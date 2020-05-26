TARGET_ARCH_LIST = ["amd64"]

def main(ctx):
  pipeline_list = []
  pipeline_list.extend([pipeline(arch) for arch in TARGET_ARCH_LIST])
  return pipeline_list

def pipeline(arch):
  return {
    "kind": "pipeline",
    "type": "docker",
    "name": "default-" + arch,
    "platform": {
      "arch": arch
    },
    "steps": [
      {
        "name": "build",
        "image": "yaamai/vlang:latest",
        "commands": [
          "v -o main.c main.v",
	  "gcc main.c -o wh -static"
        ]
      },
      {
        "name": "upx",
        "image": "yaamai/upx:latest",
        "commands": [
          "upx -v --best wh",
          "upx -v -t wh"
        ]
      },
      {
        "name": "publish release",
        "image": "plugins/github-release",
        "settings": {
          "api_key": {
            "from_secret": "github_api_key"
          },
          "files": "wh"
        },
        "when": {
          "event": ["tag"]
        }
      }
    ]
  }
