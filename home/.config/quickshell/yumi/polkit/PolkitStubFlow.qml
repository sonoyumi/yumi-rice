import QtQuick

// Заглушка AuthFlow (те же имена, что в Quickshell.Services.Polkit) для превью окна — без polkit и PAM.
// Ведёт себя как настоящий поток с /etc/pam.d/polkit-1: touch — сначала «палец» (pam_fprintd, 10 с), потом пароль;
// неверный пароль — authenticationFailed и сразу новая сессия (как AuthFlow::completed → setupSession).
// Верный пароль — строка password («yumi»). Порядок при успехе как у агента: isCompleted (агент обнуляет flow) → сигнал.
Item {
    id: f
    property string message: ""
    property string iconName: ""
    property string actionId: ""
    property string cookie: "preview"
    property var identities: []
    property var selectedIdentity: null
    property bool isResponseRequired: false
    property string inputPrompt: ""
    property bool responseVisible: false
    property string supplementaryMessage: ""
    property bool supplementaryIsError: false
    property bool isCompleted: false
    property bool isSuccessful: false
    property bool isCancelled: false
    property bool failed: false
    property bool touch: false
    property string password: "yumi"
    property int fpWaitMs: 10000
    signal authenticationSucceeded()
    signal authenticationFailed()
    signal authenticationRequestCancelled()

    function setupSession() {
        isResponseRequired = false; inputPrompt = ""
        if (touch) { supplementaryMessage = "Place your finger on the fingerprint reader"; supplementaryIsError = false; fp.restart() }
        else req.restart()
    }
    function request() { inputPrompt = "Password: "; responseVisible = false; isResponseRequired = true }
    function submit(v) {
        if (!isResponseRequired || isCompleted) return
        isResponseRequired = false; inputPrompt = ""
        check.pw = v; check.restart()
    }
    function cancelAuthenticationRequest() {
        if (isCompleted) return
        fp.stop(); req.stop(); check.stop()
        isCancelled = true; isCompleted = true
    }
    // превью Touch ID: промах (pam_fprintd: «Failed to match fingerprint») и совпадение
    function fpMiss() { if (!fp.running) return; supplementaryMessage = "Failed to match fingerprint"; supplementaryIsError = true; fp.restart() }
    function fpMatch() { if (!fp.running) return; fp.stop(); done(true) }
    function done(ok) {
        if (ok) { isSuccessful = true; isCompleted = true; authenticationSucceeded() }
        else { failed = true; authenticationFailed(); setupSession() }
    }

    Timer { id: fp; interval: f.fpWaitMs; onTriggered: f.request() }          // палец не приложен — PAM переходит к паролю
    Timer { id: req; interval: 150; onTriggered: f.request() }
    Timer { id: check; property string pw: ""; interval: 650; onTriggered: { const ok = pw === f.password; pw = ""; f.done(ok) } }
    Component.onCompleted: setupSession()
}
