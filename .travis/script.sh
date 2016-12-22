PRESET=$1

case $PRESET in
    test)
        MIX_ENV=test mix coveralls.travis
        ;;
    dialyzer)
        mix dialyzer
        ;;
    *)
        echo "Invalid preset: $PRESET"
        exit 1
        ;;
esac
