  preflight do
    # 🚀 THE GATEKEEPER SLAYER: Strip quarantine metadata cleanly while inside the Cask staging sandbox!
    system "/usr/bin/xattr", "-cr", "#{staged_path}/FamiStudio.app"

    # FIX DOUBLE-CLICK: Inject environment variables into the App Bundle's Info.plist
    plist_path = "#{staged_path}/FamiStudio.app/Contents/Info.plist"
    
    if File.exist?(plist_path)
      chosen_dotnet_root = if File.exist?("#{HOMEBREW_PREFIX}/opt/dotnet@8/bin/dotnet")
        "#{HOMEBREW_PREFIX}/opt/dotnet@8/libexec"
      else
        "#{HOMEBREW_PREFIX}/opt/dotnet/libexec"
      end

      system "/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment dict", plist_path
      system "/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:DOTNET_ROOT string '#{chosen_dotnet_root}'", plist_path
      system "/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:DOTNET_ROLL_FORWARD string 'LatestMajor'", plist_path
      system "/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:DOTNET_ROLL_FORWARD_ON_NO_CANDIDATE_FX string '2'", plist_path
    end

    # FIX TERMINAL CALLS: Generate the fallback terminal path shim script
    wrapper_path = "#{staged_path}/famistudio.wrapper.sh"
    File.write(wrapper_path, <<~EOS)
      #!/bin/zsh
      if command -v dotnet >/dev/null 2>&1; then
          DOTNET_BIN=$(command -v dotnet)
      elif [ -f "#{HOMEBREW_PREFIX}/bin/dotnet" ]; then
          DOTNET_BIN="#{HOMEBREW_PREFIX}/bin/dotnet"
      elif [ -f "#{HOMEBREW_PREFIX}/opt/dotnet@8/bin/dotnet" ]; then
          DOTNET_BIN="#{HOMEBREW_PREFIX}/opt/dotnet@8/bin/dotnet"
      elif [ -f "/usr/local/share/dotnet/dotnet" ]; then
          DOTNET_BIN="/usr/local/share/dotnet/dotnet"
      else
          echo "❌ Error: A valid .NET Runtime environment could not be located."
          exit 1
      fi

      export DOTNET_ROOT=$(dirname "$(realpath "$DOTNET_BIN")")
      export DOTNET_ROLL_FORWARD="LatestMajor"
      export DOTNET_ROLL_FORWARD_ON_NO_CANDIDATE_FX=2

      exec "$DOTNET_BIN" exec "#{appdir}/FamiStudio.app/Contents/MacOS/FamiStudio.dll" "$@"
    EOS

    FileUtils.chmod("+x", wrapper_path)
  end
