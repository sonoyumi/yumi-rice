// Экономия памяти (yumi-rice). Откат: удалить этот файл и перезапустить Firefox.
user_pref("dom.ipc.processCount.webIsolated", 1);                       // один процесс на сайт, а не несколько
user_pref("browser.sessionhistory.max_total_viewers", 2);               // меньше страниц «Назад» держится в памяти
user_pref("browser.tabs.unloadOnLowMemory", true);                      // выгружать вкладки при нехватке памяти
user_pref("browser.tabs.min_inactive_duration_before_unload", 300000);  // выгружать можно через 5 мин без дела (было 10)
user_pref("browser.low_commit_space_threshold_percent", 15);            // считать память на исходе раньше
// 08.10.2026: ещё экономия (откат: вернуть user.js.bak-2026-10-08)
user_pref("dom.ipc.processPrelaunch.enabled", false);                    // не держать запасной процесс заранее
user_pref("dom.ipc.processCount", 4);                                    // не больше 4 процессов для обычных страниц
user_pref("browser.sessionstore.restore_on_demand", true);               // вкладки после перезапуска грузятся только по клику
user_pref("browser.startup.page", 3);                                    // открывать прежние окна и вкладки
