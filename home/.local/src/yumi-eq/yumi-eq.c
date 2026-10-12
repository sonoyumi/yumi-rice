// yumi-eq — эквалайзер в пилюле плеера Waybar (CFFI-модуль: Waybar загружает .so и отдаёт ему виджет).
//
// Одна cava на все мониторы (общее состояние модуля), запускается только пока плеер играет, слушает
// «монитор» текущего выхода звука через pulse (не микрофон: микрофон Bluetooth-наушников переводит
// их в режим гарнитуры). cava шлёт ~30 кадров/с, модуль сглаживает до частоты экрана (frame clock GTK).
// Скруглённые столбики с градиентом и падающими пиками; цвета — @yb-acc / @yb-acc5 из CSS Waybar
// (yumi-accent, из обоев), меняются вместе с обоями. Пауза — столбики оседают; ничего не играет — скрыт.
//
// Конфиг Waybar ("cffi/yumi-eq"): module_path, bars, bar-width, gap, height, margin-left, margin-right (px),
// on-click, on-click-middle, on-click-right, on-scroll-up, on-scroll-down (строки-команды).
// Сборка: make (gcc). Откат: yumi-eq-uninstall
#include "waybar_cffi_module.h"

#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>

#define MAXB 32

const size_t wbcffi_version = 2;

typedef enum { ST_STOPPED, ST_PAUSED, ST_PLAYING } PlayState;

typedef struct {
  GtkWidget *box, *area;
  int bars;
  double bw, gap, height;
  int ml, mr;             // поля внутри области рисования (margin виджета Waybar срезает)
  gboolean island;        // стиль «island»: 5 мягких столбиков по центру, как музыка в Dynamic Island
  gboolean classic;       // стиль «classic»: как в первом макете — тонкие столбики цвета акцента от низа
  double disp[MAXB], peak[MAXB], hold[MAXB];
  double fade;            // 0 — пауза (осели), 1 — играет
  double drawn[MAXB + 1]; // высоты (px), которые сейчас на экране: меньше полпикселя разницы — не перерисовываем
  guint tick_id;
  gint64 last_us;
  char *cmd[5];           // click, middle, right, scroll up, scroll down
} Eq;

// ---------- общее состояние: одна cava и один опрос плеера на все экземпляры ----------
static GList *g_eqs = NULL;
static PlayState g_state = ST_STOPPED;
static double g_target[MAXB];
static int g_bars = 12;
static GPid g_cava_pid = 0;
static GIOChannel *g_cava_ch = NULL;
static guint g_cava_watch = 0, g_poll_id = 0;
static char *g_sink = NULL;
static guint8 g_buf[MAXB * 2];
static gsize g_buf_len = 0;
static gboolean g_polling = FALSE;
// Уровни для других окон (меню «Музыка», yumi-player): $XDG_RUNTIME_DIR/yumi-eq.levels —
// g_bars байт uint8 (0..255), перезаписывается на каждом кадре cava (~30/с); нет файла — ничего не играет
static int g_levels_fd = -1;
static char *g_levels_path = NULL;

static void levels_close(void) {
  if (g_levels_fd >= 0) { close(g_levels_fd); g_levels_fd = -1; }
  if (g_levels_path) unlink(g_levels_path);
}

static void eq_wake(Eq *eq);

static void cava_stop(void) {
  if (g_cava_watch) { g_source_remove(g_cava_watch); g_cava_watch = 0; }
  if (g_cava_ch) { g_io_channel_shutdown(g_cava_ch, FALSE, NULL); g_io_channel_unref(g_cava_ch); g_cava_ch = NULL; }
  if (g_cava_pid) { kill(g_cava_pid, SIGTERM); g_spawn_close_pid(g_cava_pid); g_cava_pid = 0; }
  memset(g_target, 0, sizeof g_target);
  g_buf_len = 0;
  levels_close();
}

static gboolean on_cava_data(GIOChannel *ch, GIOCondition cond, gpointer _u) {
  (void)_u;
  if (cond & (G_IO_HUP | G_IO_ERR)) { g_cava_watch = 0; cava_stop(); return G_SOURCE_REMOVE; }
  guint8 tmp[4096];
  gsize n = 0;
  GIOStatus st = g_io_channel_read_chars(ch, (gchar *)tmp, sizeof tmp, &n, NULL);
  if (st == G_IO_STATUS_EOF || st == G_IO_STATUS_ERROR) { g_cava_watch = 0; cava_stop(); return G_SOURCE_REMOVE; }
  gsize frame = (gsize)g_bars * 2;
  for (gsize i = 0; i < n; i++) {           // кадр = bars × uint16 (data_format binary, 16bit)
    g_buf[g_buf_len++] = tmp[i];
    if (g_buf_len == frame) {
      guint8 lv[MAXB];
      for (int b = 0; b < g_bars; b++) {
        guint16 v = (guint16)(g_buf[2 * b] | (g_buf[2 * b + 1] << 8));
        g_target[b] = v / 65535.0;
        lv[b] = (guint8)(v >> 8);
      }
      g_buf_len = 0;
      if (g_levels_fd < 0) {
        if (!g_levels_path) g_levels_path = g_build_filename(g_get_user_runtime_dir(), "yumi-eq.levels", NULL);
        g_levels_fd = open(g_levels_path, O_WRONLY | O_CREAT | O_CLOEXEC, 0644);
      }
      if (g_levels_fd >= 0 && pwrite(g_levels_fd, lv, g_bars, 0) < 0) levels_close();
    }
  }
  return G_SOURCE_CONTINUE;
}

static void cava_child_exit(GPid pid, gint status, gpointer _u) {
  (void)status; (void)_u;
  g_spawn_close_pid(pid);
}

static void cava_start(const char *sink) {
  cava_stop();
  char *conf = g_build_filename(g_get_user_runtime_dir(), "yumi-eq-cava.conf", NULL);
  char *src = sink && *sink ? g_strdup_printf("%s.monitor", sink) : g_strdup("auto");
  char *body = g_strdup_printf(
      "[general]\nbars = %d\nframerate = 60\nautosens = 1\n"
      "[input]\nmethod = pulse\nsource = %s\n"
      "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = binary\nbit_format = 16bit\n"
      "channels = mono\nmono_option = average\n"
      "[smoothing]\nmonstercat = 1\nnoise_reduction = 40\n", g_bars, src);
  g_file_set_contents(conf, body, -1, NULL);
  char *argv[] = {"cava", "-p", conf, NULL};
  gint out = -1;
  if (g_spawn_async_with_pipes(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD |
                               G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, &g_cava_pid, NULL, &out, NULL, NULL)) {
    g_child_watch_add(g_cava_pid, cava_child_exit, NULL);
    g_cava_ch = g_io_channel_unix_new(out);
    g_io_channel_set_encoding(g_cava_ch, NULL, NULL);
    g_io_channel_set_buffered(g_cava_ch, FALSE);
    g_io_channel_set_close_on_unref(g_cava_ch, TRUE);
    g_cava_watch = g_io_add_watch(g_cava_ch, G_IO_IN | G_IO_HUP | G_IO_ERR, on_cava_data, NULL);
  } else {
    g_cava_pid = 0;
  }
  g_free(body); g_free(src); g_free(conf);
}

static char *run_line(const char *cmd) {         // короткая команда → первая строка вывода
  char *out = NULL;
  if (!g_spawn_command_line_sync(cmd, &out, NULL, NULL, NULL)) return g_strdup("");
  char *nl = strchr(out, '\n');
  if (nl) *nl = 0;
  return out;
}

static void eq_wake(Eq *eq);
static gboolean g_off;

static void set_state(PlayState st) {
  char *offp = g_build_filename(g_get_user_runtime_dir(), "yumi-eq.off", NULL);
  g_off = g_file_test(offp, G_FILE_TEST_EXISTS);
  g_free(offp);
  if (st == ST_PLAYING) {
    char *sink = run_line("pactl get-default-sink");
    if (!g_cava_pid || g_strcmp0(sink, g_sink) != 0) {   // смена наушники ↔ динамики — перезапуск
      g_free(g_sink); g_sink = g_strdup(sink);
      cava_start(sink);
    }
    g_free(sink);
  } else if (g_cava_pid) {
    cava_stop();
    g_free(g_sink); g_sink = NULL;
  }
  g_state = st;
  for (GList *l = g_eqs; l; l = l->next) eq_wake(l->data);
}

static void on_status(GObject *src, GAsyncResult *res, gpointer _u) {
  (void)_u;
  char *out = NULL;
  g_polling = FALSE;
  if (!g_subprocess_communicate_utf8_finish(G_SUBPROCESS(src), res, &out, NULL, NULL)) out = NULL;
  PlayState st = ST_STOPPED;
  if (out && g_str_has_prefix(out, "Playing")) st = ST_PLAYING;
  else if (out && g_str_has_prefix(out, "Paused")) st = ST_PAUSED;
  g_free(out);
  set_state(st);
}

static gboolean poll_status(gpointer _u) {         // раз в секунду, асинхронно — бар не подвисает
  (void)_u;
  if (g_polling) return G_SOURCE_CONTINUE;
  GSubprocess *p = g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_SILENCE, NULL,
                                    "sh", "-c", "playerctl -p playerctld status 2>/dev/null || playerctl status",
                                    NULL);
  if (!p) return G_SOURCE_CONTINUE;
  g_polling = TRUE;
  g_subprocess_communicate_utf8_async(p, NULL, NULL, on_status, NULL);
  g_object_unref(p);
  return G_SOURCE_CONTINUE;
}

// ---------- отрисовка ----------
static void lookup(GtkWidget *w, const char *name, const char *fallback, GdkRGBA *c) {
  GtkStyleContext *ctx = gtk_widget_get_style_context(w);
  if (!gtk_style_context_lookup_color(ctx, name, c)) gdk_rgba_parse(c, fallback);
}

static void rounded(cairo_t *cr, double x, double y, double w, double h, double r) {
  r = fmin(r, fmin(w, h) / 2);
  cairo_new_sub_path(cr);
  cairo_arc(cr, x + w - r, y + r, r, -G_PI / 2, 0);
  cairo_arc(cr, x + w - r, y + h - r, r, 0, G_PI / 2);
  cairo_arc(cr, x + r, y + h - r, r, G_PI / 2, G_PI);
  cairo_arc(cr, x + r, y + r, r, G_PI, 3 * G_PI / 2);
  cairo_close_path(cr);
}

static GdkRGBA rgba_mix(GdkRGBA a, GdkRGBA b, double t) {
  GdkRGBA c = {a.red + (b.red - a.red) * t, a.green + (b.green - a.green) * t, a.blue + (b.blue - a.blue) * t, 1};
  return c;
}

// «island»: 5 скруглённых столбиков по центру высоты; оттенки обоев main-fg → акцент → тёмный акцент
static void draw_island(GtkWidget *w, cairo_t *cr, Eq *eq) {
  GdkRGBA fg, acc, acc5;
  lookup(w, "main-fg", "#e6f3f6", &fg);
  lookup(w, "yb-acc", "#9ad8e6", &acc);
  lookup(w, "yb-acc5", "#6598a3", &acc5);
  GdkRGBA cols[5] = {fg, rgba_mix(fg, acc, 0.5), acc, rgba_mix(acc, acc5, 0.45), rgba_mix(acc, acc5, 0.8)};
  double H = gtk_widget_get_allocated_height(w), W = gtk_widget_get_allocated_width(w);
  double eh = fmin(eq->height, H - 2);
  double total = 5 * eq->bw + 4 * eq->gap;
  double x0 = eq->ml + floor((W - eq->ml - eq->mr - total) / 2), mid = H / 2;
  for (int i = 0; i < 5; i++) {
    double bh = fmax(eq->bw, eh * (0.18 + 0.82 * eq->disp[i]) * eq->fade + eq->bw * (1 - eq->fade));
    cairo_set_source_rgba(cr, cols[i].red, cols[i].green, cols[i].blue, 0.45 + 0.55 * eq->fade);
    rounded(cr, x0 + i * (eq->bw + eq->gap), mid - bh / 2, eq->bw, bh, eq->bw / 2);
    cairo_fill(cr);
  }
}

// «classic» — 1 в 1 первый макет: N столбиков сплошным @yb-acc, растут от низа, скругление 2 px;
// высота 18…100 %, на паузе 12 % и бледнее (opacity .45)
static void draw_classic(GtkWidget *w, cairo_t *cr, Eq *eq) {
  GdkRGBA acc;
  lookup(w, "yb-acc", "#9ad8e6", &acc);
  double H = gtk_widget_get_allocated_height(w), W = gtk_widget_get_allocated_width(w);
  double eh = fmin(eq->height, H - 2);
  double total = eq->bars * eq->bw + (eq->bars - 1) * eq->gap;
  double x0 = eq->ml + floor((W - eq->ml - eq->mr - total) / 2), base = floor((H + eh) / 2);
  cairo_set_source_rgba(cr, acc.red, acc.green, acc.blue, 0.45 + 0.55 * eq->fade);
  for (int i = 0; i < eq->bars; i++) {
    double f = (0.18 + 0.82 * eq->disp[i]) * eq->fade + 0.12 * (1 - eq->fade);
    double bh = fmax(1.5, eh * f);
    rounded(cr, x0 + i * (eq->bw + eq->gap), base - bh, eq->bw, bh, fmin(2.0, eq->bw / 2));
  }
  cairo_fill(cr);
}

static gboolean on_draw(GtkWidget *w, cairo_t *cr, gpointer data) {
  Eq *eq = data;
  if (eq->island) { draw_island(w, cr, eq); return FALSE; }
  if (eq->classic) { draw_classic(w, cr, eq); return FALSE; }
  GdkRGBA top, bot;
  lookup(w, "yb-acc", "#9ad8e6", &top);
  lookup(w, "yb-acc5", "#6598a3", &bot);
  double H = gtk_widget_get_allocated_height(w), W = gtk_widget_get_allocated_width(w);
  if (g_getenv("YUMI_EQ_DEBUG") || g_file_test("/run/user/1001/yumi-eq.debug", G_FILE_TEST_EXISTS)) {
    static double lw = -1, lh = -1;
    if (W != lw || H != lh) {
      lw = W; lh = H;
      GtkAllocation a, pa; gtk_widget_get_allocation(w, &a);
      GtkWidget *par = gtk_widget_get_parent(gtk_widget_get_parent(w));
      gtk_widget_get_allocation(par, &pa);
      FILE *f = fopen("/run/user/1001/yumi-eq.log", "a");
      if (f) { fprintf(f, "area %dx%d at %d,%d; root(%s) %dx%d at %d,%d; req %d\n", a.width, a.height, a.x, a.y,
                       G_OBJECT_TYPE_NAME(par), pa.width, pa.height, pa.x, pa.y,
                       eq->ml + eq->mr + (int)ceil(eq->bars * eq->bw + (eq->bars - 1) * eq->gap)); fclose(f); }
    }
  }
  double total = eq->bars * eq->bw + (eq->bars - 1) * eq->gap;
  // высота — сколько Waybar реально выделил (бывает меньше заказанной): иначе низ столбиков обрезается
  double eh = fmin(eq->height, H - 2);
  double x0 = eq->ml + floor((W - eq->ml - eq->mr - total) / 2), base = floor((H + eh) / 2);
  double r = eq->bw / 2;
  for (int i = 0; i < eq->bars; i++) {
    double x = x0 + i * (eq->bw + eq->gap);
    double lv = pow(eq->disp[i], 0.75);                     // громкость на глаз: тихое заметнее
    double h = fmax(eq->bw, lv * (eh - 3) * eq->fade + eq->bw * (1 - eq->fade));
    cairo_pattern_t *g = cairo_pattern_create_linear(0, base - eh, 0, base);
    double a = 0.45 + 0.55 * eq->fade;
    cairo_pattern_add_color_stop_rgba(g, 0, fmin(1, top.red * 1.15), fmin(1, top.green * 1.15),
                                      fmin(1, top.blue * 1.15), a);
    cairo_pattern_add_color_stop_rgba(g, 1, bot.red, bot.green, bot.blue, a * 0.85);
    cairo_set_source(cr, g);
    rounded(cr, x, base - h, eq->bw, h, r);
    cairo_fill(cr);
    cairo_pattern_destroy(g);
    if (eq->fade > 0.05 && eq->peak[i] > 0.04) {           // пиковая точка, падает с задержкой
      double py = base - fmax(h, pow(eq->peak[i], 0.75) * (eh - 3)) - 2.0;
      cairo_set_source_rgba(cr, top.red, top.green, top.blue, 0.9 * eq->fade);
      rounded(cr, x, py, eq->bw, 1.6, 0.8);
      cairo_fill(cr);
    }
  }
  return FALSE;
}

static gboolean on_tick(GtkWidget *w, GdkFrameClock *clock, gpointer data) {
  Eq *eq = data;
  gint64 now = gdk_frame_clock_get_frame_time(clock);
  double dt = eq->last_us ? fmin(0.05, (now - eq->last_us) / 1e6) : 0.016;
  eq->last_us = now;
  gboolean playing = g_state == ST_PLAYING;
  eq->fade += ((playing ? 1.0 : 0.0) - eq->fade) * (1 - exp(-dt * 6));
  double moving = fabs((playing ? 1.0 : 0.0) - eq->fade);
  int n = eq->island ? 5 : eq->bars;
  for (int i = 0; i < n; i++) {
    double tgt = 0;
    if (playing && eq->island) {                  // 12 полос cava → 5 столбиков, громкость «на глаз»
      int a = i * g_bars / 5, b = (i + 1) * g_bars / 5;
      for (int k = a; k < b; k++) tgt += g_target[k];
      tgt = pow(tgt / MAX(1, b - a), 0.7);
    } else if (playing) {
      tgt = g_target[i * g_bars / eq->bars];
    }
    double rate = tgt > eq->disp[i] ? 40.0 : 18.0;        // резкий подъём и быстрый спад — в ритм трека
    eq->disp[i] += (tgt - eq->disp[i]) * (1 - exp(-dt * rate));
    if (eq->disp[i] >= eq->peak[i]) { eq->peak[i] = eq->disp[i]; eq->hold[i] = 0.35; }
    else if ((eq->hold[i] -= dt) < 0) eq->peak[i] = fmax(0, eq->peak[i] - dt * 0.55);
    moving += eq->disp[i] + eq->peak[i];
  }
  // перерисовка только при видимом изменении: сдвиг любого столбика (или пика) хотя бы на 0.5 px.
  // Глазу это незаметно, а пустых кадров при ровном звуке и в паузах становится заметно меньше
  gboolean changed = FALSE;
  for (int i = 0; i < n && !changed; i++) {
    double px = (eq->disp[i] * eq->fade + (1 - eq->fade) * 0.12) * eq->height;
    double pk = eq->peak[i] * eq->height * eq->fade;
    if (fabs(px - eq->drawn[i]) >= 0.5 || (!eq->island && !eq->classic && fabs(pk - eq->drawn[MAXB]) >= 0.5))
      changed = TRUE;
  }
  if (changed) {
    for (int i = 0; i < n; i++) eq->drawn[i] = (eq->disp[i] * eq->fade + (1 - eq->fade) * 0.12) * eq->height;
    gtk_widget_queue_draw(w);
  }
  if (g_off || (!playing && moving < 0.01)) {                          // всё осело — не рисуем впустую
    eq->tick_id = 0;
    eq->last_us = 0;
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

// служебный выключатель для замеров: есть $XDG_RUNTIME_DIR/yumi-eq.off — анимация стоит (cava работает)
static gboolean g_off = FALSE;

static void eq_wake(Eq *eq) {
  // show(), не show_all(): у box стоит no_show_all (чтобы Waybar не показал его сам), а show_all его пропускает
  if (g_state == ST_STOPPED) gtk_widget_hide(eq->box);
  else gtk_widget_show(eq->box);
  if (!eq->tick_id && g_state != ST_STOPPED && !g_off)
    eq->tick_id = gtk_widget_add_tick_callback(eq->area, on_tick, eq, NULL);
}

// ---------- клики и колесо — как у остальной пилюли плеера ----------
static void spawn(const char *cmd) {
  if (cmd && *cmd) g_spawn_command_line_async(cmd, NULL);
}

static gboolean on_button(GtkWidget *w, GdkEventButton *ev, gpointer data) {
  (void)w;
  Eq *eq = data;
  if (ev->type != GDK_BUTTON_PRESS) return FALSE;
  spawn(eq->cmd[ev->button == 2 ? 1 : ev->button == 3 ? 2 : 0]);
  return TRUE;
}

static gboolean on_scroll(GtkWidget *w, GdkEventScroll *ev, gpointer data) {
  (void)w;
  Eq *eq = data;
  double dy = 0;
  if (ev->direction == GDK_SCROLL_UP) dy = -1;
  else if (ev->direction == GDK_SCROLL_DOWN) dy = 1;
  else if (ev->direction == GDK_SCROLL_SMOOTH) gdk_event_get_scroll_deltas((GdkEvent *)ev, NULL, &dy);
  if (dy < 0) spawn(eq->cmd[3]);
  else if (dy > 0) spawn(eq->cmd[4]);
  return TRUE;
}

// ---------- CFFI ----------
static char *json_str(const char *v) {             // ABI 2: значение — JSON; строку снимаем с кавычек
  size_t n = strlen(v);
  if (n >= 2 && v[0] == '"' && v[n - 1] == '"') {
    char *s = g_strndup(v + 1, n - 2), *o = s;
    for (char *p = s; *p; p++) {                     // \" и \\ → символ
      if (*p == '\\' && p[1]) p++;
      *o++ = *p;
    }
    *o = 0;
    return s;
  }
  return g_strdup(v);
}

void *wbcffi_init(const wbcffi_init_info *info, const wbcffi_config_entry *cfg, size_t n) {
  Eq *eq = g_new0(Eq, 1);
  eq->bars = 12; eq->bw = 3; eq->gap = 2; eq->height = 16;
  int ml = 2, mr = 10;
  const char *keys[5] = {"on-click", "on-click-middle", "on-click-right", "on-scroll-up", "on-scroll-down"};
  for (size_t i = 0; i < n; i++) {
    const char *k = cfg[i].key, *v = cfg[i].value;
    if (!strcmp(k, "bars")) eq->bars = CLAMP(atoi(v), 4, MAXB);
    else if (!strcmp(k, "bar-width")) eq->bw = CLAMP(atof(v), 1, 12);
    else if (!strcmp(k, "gap")) eq->gap = CLAMP(atof(v), 0, 12);
    else if (!strcmp(k, "height")) eq->height = CLAMP(atof(v), 6, 40);
    else if (!strcmp(k, "margin-left")) ml = CLAMP(atoi(v), 0, 40);
    else if (!strcmp(k, "margin-right")) mr = CLAMP(atoi(v), 0, 40);
    else if (!strcmp(k, "style")) { eq->island = strstr(v, "island") != NULL; eq->classic = strstr(v, "classic") != NULL; }
    for (int c = 0; c < 5; c++)
      if (!strcmp(k, keys[c])) eq->cmd[c] = json_str(v);
  }
  g_bars = 12;                                   // cava всегда 12 полос: их читают плеер и меню (yumi-eq.levels)

  GtkContainer *root = info->get_root_widget(info->obj);
  eq->box = gtk_event_box_new();
  gtk_widget_set_name(eq->box, "yumi-eq");
  gtk_widget_add_events(eq->box, GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK | GDK_BUTTON_PRESS_MASK);
  g_signal_connect(eq->box, "button-press-event", G_CALLBACK(on_button), eq);
  g_signal_connect(eq->box, "scroll-event", G_CALLBACK(on_scroll), eq);
  eq->area = gtk_drawing_area_new();
  eq->ml = ml; eq->mr = mr;
  int nb = eq->island ? 5 : eq->bars;
  gtk_widget_set_size_request(eq->area, ml + mr + (int)ceil(nb * eq->bw + (nb - 1) * eq->gap), (int)eq->height);
  gtk_widget_set_valign(eq->area, GTK_ALIGN_FILL);
  g_signal_connect(eq->area, "draw", G_CALLBACK(on_draw), eq);
  gtk_container_add(GTK_CONTAINER(eq->box), eq->area);
  gtk_widget_show(eq->area);
  gtk_container_add(root, eq->box);
  gtk_widget_set_no_show_all(eq->box, TRUE);     // показываем сами — только когда что-то играет

  g_eqs = g_list_append(g_eqs, eq);
  if (!g_poll_id) {
    g_poll_id = g_timeout_add_seconds(1, poll_status, NULL);
    poll_status(NULL);
  }
  eq_wake(eq);
  return eq;
}

void wbcffi_deinit(void *instance) {
  Eq *eq = instance;
  g_eqs = g_list_remove(g_eqs, eq);
  if (eq->tick_id) gtk_widget_remove_tick_callback(eq->area, eq->tick_id);
  for (int c = 0; c < 5; c++) g_free(eq->cmd[c]);
  g_free(eq);
  if (!g_eqs) {                                       // последний экземпляр — гасим cava и опрос
    if (g_poll_id) { g_source_remove(g_poll_id); g_poll_id = 0; }
    cava_stop();
    g_free(g_sink); g_sink = NULL;
  }
}

void wbcffi_update(void *instance) { (void)instance; }
void wbcffi_refresh(void *instance, int sig) { (void)instance; (void)sig; poll_status(NULL); }
void wbcffi_doaction(void *instance, const char *name) { (void)instance; (void)name; }
