cask "famistudio" do
  version "4.5.1"
  sha256 "b6794d5a6074dd5cd0bccf2a98cf5bf582042362ed84b7c8228804b09d1f5fd3"

  # Cleanly separate the version parsing variable first
  stripped_version = version.tr(".", "")

  # The exact, fully qualified repository URL structure that works
  url "https://github.com/BleuBleu/FamiStudio/releases/download/#{version}/FamiStudio#{stripped_version}-MacOS.zip",
      verified: "github.com/BleuBleu/FamiStudio/"
  name "FamiStudio"
  desc "NES Music Editor (Environment Agnostic Edition)"
  homepage "https://famistudio.org"

  livecheck do
    url "https://github.com/BleuBleu/FamiStudio/releases"
    strategy :page_match do |page|
      page.scan(%r{href=.*?/download/v?(\d+(?:\.\d+)+)/FamiStudio\d+-MacOS\.zip}i).map { |match| match }
    end
  end

  depends_on formula: "dotnet@8"

  app "FamiStudio.app"
  binary "famistudio.wrapper.sh", target: "famistudio"

  preflight do
    # 1. Strip macOS Gatekeeper sandbox quarantine tracking flags completely
    system "/usr/bin/xattr", "-cr", "#{staged_path}/FamiStudio.app"

    # 2. Overwrite application startup binary path with a runtime fallback engine
    native_exec_path = "#{staged_path}/FamiStudio.app/Contents/MacOS/main.command"
    
    File.write(native_exec_path, <<~'EOS')
      #!/bin/zsh
      # Fully sandbox runtime execution matrices against outer profile leakage
      unset DOTNET_MULTILEVEL_LOOKUP
      unset MSBUILD_EXE_PATH

      # Step A: Dynamic Runtime Binary Discovery Chain
      if [ -f "$HOME/homebrew/opt/dotnet@8/bin/dotnet" ]; then
          DOTNET_BIN="$HOME/homebrew/opt/dotnet@8/bin/dotnet"
      elif [ -f "$HOME/homebrew/opt/dotnet/bin/dotnet" ]; then
          DOTNET_BIN="$HOME/homebrew/opt/dotnet/bin/dotnet"
      elif [ -f "$HOME/homebrew/bin/dotnet" ]; then
          DOTNET_BIN="$HOME/homebrew/bin/dotnet"
      elif command -v dotnet >/dev/null 2>&1; then
          DOTNET_BIN=$(command -v dotnet)
      elif [ -f "/usr/local/share/dotnet/dotnet" ]; then
          DOTNET_BIN="/usr/local/share/dotnet/dotnet"
      else
          # Display visual GUI fallback warning notification popup if everything is broken
          osascript -e 'display dialog "❌ FamiStudio Runtime Fault:\nA compatible .NET execution runtime could not be resolved.\n\nPlease reinstall via terminal: brew install dotnet@8" buttons {"OK"} default button "OK" with icon stop'
          exit 1
      fi

      # Step B: Resolve downstream system symlinks securely
      REAL_DOTNET=$(readlink -f "$DOTNET_BIN" 2>/dev/null || realpath "$DOTNET_BIN")
      
      # Correct path context alignment for underlying target SDK shared runtimes
      if [ -d "$(dirname "$REAL_DOTNET")/../libexec" ]; then
          export DOTNET_ROOT="$(cd "$(dirname "$REAL_DOTNET")/../libexec" && pwd)"
      else
          export DOTNET_ROOT="$(cd "$(dirname "$REAL_DOTNET")" && pwd)"
      fi

      # Step C: Inject version cross-compatibility parameters
      export DOTNET_ROLL_FORWARD="LatestMajor"
      export DOTNET_ROLL_FORWARD_ON_NO_CANDIDATE_FX=2

      # Step D: Pull absolute runtime execution context relative to current location
      APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

      # Run execution engine handover cleanly
      exec "$REAL_DOTNET" exec "$APP_DIR/Contents/MacOS/FamiStudio.dll" "$@"
    EOS
    
    FileUtils.chmod("+x", native_exec_path)

    # 3. Synchronize terminal CLI bindings directly to our unified self-repair runner
    wrapper_path = "#{staged_path}/famistudio.wrapper.sh"
    File.write(wrapper_path, <<~EOS)
      #!/bin/zsh
      exec "#{appdir}/FamiStudio.app/Contents/MacOS/main.command" "$@"
    EOS
    
    FileUtils.chmod("+x", wrapper_path)
  end

  postflight do
    # 4. Enforce structural user space permissions safety overrides
    system "/bin/chmod", "-R", "u+rwx", "#{appdir}/FamiStudio.app"

    # 5. Native deployment processing array for peripheral asset workspaces
    dest_dir = File.expand_path("~/Documents/FamiStudio")
    FileUtils.mkdir_p(dest_dir)
    ["Demo Instruments", "Demo Songs"].each do |folder|
      src = "#{staged_path}/#{folder}"
      dst = "#{dest_dir}/#{folder}"
      if File.exist?(src) && !File.exist?(dst)
        FileUtils.cp_r(src, dst)
      end
    end
  end

  caveats <<~EOS
    Your FamiStudio configuration engine has been reinforced with a self-healing patch.
    Sample tracking content assets are located directly within your Documents path:
      ~/Documents/FamiStudio/
  EOS

  zap trash: [
    "~/Library/Application Support/FamiStudio",
    "~/Library/Preferences/FamiStudio",
  ]
end