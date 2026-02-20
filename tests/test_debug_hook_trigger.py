import subprocess, json, pytest

HOOK = "hooks/feedback/context-enrichment.sh"

def run_hook(prompt):
    r = subprocess.run(["bash", HOOK], input=json.dumps({"prompt": prompt}),
                       capture_output=True, text=True, timeout=10)
    return r.stdout

class TestDebugHookTrigger:
    def test_chinese_error(self):
        assert "🐛" in run_hook("测试报错了，帮我看看")

    def test_english_error(self):
        assert "🐛" in run_hook("tests are failing, looks like something broke")

    def test_bug_keyword(self):
        assert "🐛" in run_hook("这个 bug 怎么修")

    def test_traceback(self):
        assert "🐛" in run_hook("got a traceback in the logs")

    def test_broken_keyword(self):
        assert "🐛" in run_hook("build is broken after the last commit")

    def test_bug_english(self):
        assert "🐛" in run_hook("there's a bug in the parser")

    def test_no_false_positive_chinese(self):
        out = run_hook("帮我写个新功能")
        assert "🐛" not in out

    def test_no_false_positive_error_handling(self):
        out = run_hook("add error handling to the parser")
        assert "🐛" not in out

    def test_no_false_positive_debug_logging(self):
        out = run_hook("add debug logging to the service")
        assert "🐛" not in out
