defmodule MahaulTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import ExUnit.CaptureIO

  @env_list [
    {"MOCK__ENV__STR", "__MOCK__VAL1__"},
    {"MOCK__ENV__ENUM", "__MOCK__VAL2__"},
    {"MOCK__ENV__NUM", "10.10"},
    {"MOCK__ENV__INT", "10"},
    {"MOCK__ENV__BOOL", "true"},
    {"MOCK__ENV__PORT", "8080"},
    {"MOCK__ENV__HOST", "//example.com"},
    {"MOCK__ENV__URI", "https://example.com/something"},
    {"MOCK__ENV__STR_ENCODED", Base.encode64("__MOCK__VAL1__")},
    {"MOCK__ENV__ENUM_ENCODED", Base.encode64("__MOCK__VAL2__")},
    {"MOCK__ENV__NUM_ENCODED", Base.encode64("10.10")},
    {"MOCK__ENV__INT_ENCODED", Base.encode64("10")},
    {"MOCK__ENV__BOOL_ENCODED", Base.encode64("true")},
    {"MOCK__ENV__PORT_ENCODED", Base.encode64("8080")},
    {"MOCK__ENV__HOST_ENCODED", Base.encode64("//example.com")},
    {"MOCK__ENV__URI_ENCODED", Base.encode64("https://example.com/something")}
  ]

  setup do
    System.put_env(@env_list)

    on_exit(fn ->
      @env_list |> Enum.each(fn {key, _} -> System.delete_env(key) end)
    end)
  end

  describe "invalid options" do
    invalid_opts_samples = [
      {"Mahaul: expected options to be a non-empty keyword list, got: []", []},
      {"MOCK__ENV: expected options to be a non-empty keyword list, got: true",
       [MOCK__ENV: true]},
      {"MOCK__ENV: expected options to be a non-empty keyword list, got: []", [MOCK__ENV: []]},
      {"MOCK__ENV: expected :type to be one of [:str, :enum, :num, :int, :bool, :port, :host, :uri], got: :invalid",
       [MOCK__ENV: [type: :invalid]]},
      {"MOCK__ENV: expected :base64 to be a boolean, got: \"false\"",
       [MOCK__ENV: [type: :str, base64: "false"]]},
      {"MOCK__ENV: missing required options [:type]", [MOCK__ENV: [default: "__MOCK__"]]},
      {"MOCK__ENV: expected :choices to be a non-empty list, got: true",
       [MOCK__ENV: [type: :str, choices: true]]},
      {"MOCK__ENV: expected :choices to be a non-empty list, got: []",
       [MOCK__ENV: [type: :str, choices: []]]},
      {"MOCK__ENV: expected :defaults to be a non-empty keyword list, got: []",
       [MOCK__ENV: [type: :str, defaults: []]]},
      {"MOCK__ENV: expected :defaults :dev to be a string, got: 1000",
       [MOCK__ENV: [type: :str, defaults: [dev: 1000]]]},
      {"MOCK__ENV: expected :default to be a string, got: 1000",
       [MOCK__ENV: [type: :str, default: 1000]]},
      {"MOCK__ENV: expected :default_dev to be a string, got: false",
       [MOCK__ENV: [type: :str, default_dev: false]]},
      {"MOCK__ENV: expected :doc to be a string, got: []", [MOCK__ENV: [type: :str, doc: []]]},
      {"MOCK__ENV: expected :fun to be an atom, got: \"fun_name\"",
       [MOCK__ENV: [type: :str, fun: "fun_name"]]},
      {"MOCK__ENV: unknown option provided {:invalid_option, \"__MOCK__\"}",
       [MOCK__ENV: [type: :str, invalid_option: "__MOCK__"]]}
    ]

    for {{error, opts}, index} <- invalid_opts_samples |> Enum.with_index() do
      test "should raise exception for invalid options #{inspect(opts)}" do
        fun = fn ->
          assert_raise ArgumentError, unquote(error), fn ->
            defmodule String.to_atom("Env0.#{unquote(index)}") do
              use Mahaul, unquote(opts)
            end
          end
        end

        capture_io(:stderr, fun)
      end
    end
  end

  describe "deprecation warning" do
    test "should warn on :default_dev option" do
      fun = fn ->
        defmodule Env0.Deprecated do
          use Mahaul,
            MOCK__ENV: [type: :str, default_dev: "__MOCK__"]
        end
      end

      assert capture_io(:stderr, fun) =~
               ~s(MOCK__ENV: :default_dev option is deprecated, use :defaults instead. eg: defaults: [prod: "MY_VAL1", dev: "MY_VAL2", test: "MY_VAL3"])
    end
  end

  describe "validate/0" do
    test "should return success for valid environment variables" do
      defmodule Env1 do
        use Mahaul,
          MOCK__ENV__STR: [type: :str],
          MOCK__ENV__ENUM: [type: :enum],
          MOCK__ENV__NUM: [type: :num],
          MOCK__ENV__INT: [type: :int],
          MOCK__ENV__BOOL: [type: :bool],
          MOCK__ENV__PORT: [type: :port],
          MOCK__ENV__HOST: [type: :host],
          MOCK__ENV__URI: [type: :uri]
      end

      assert {:ok} = Env1.validate()
    end

    test "should return success for valid encoded environment variables" do
      defmodule Env1.Encoded do
        use Mahaul,
          MOCK__ENV__STR_ENCODED: [type: :str, base64: true],
          MOCK__ENV__ENUM_ENCODED: [type: :enum, base64: true],
          MOCK__ENV__NUM_ENCODED: [type: :num, base64: true],
          MOCK__ENV__INT_ENCODED: [type: :int, base64: true],
          MOCK__ENV__BOOL_ENCODED: [type: :bool, base64: true],
          MOCK__ENV__PORT_ENCODED: [type: :port, base64: true],
          MOCK__ENV__HOST_ENCODED: [type: :host, base64: true],
          MOCK__ENV__URI_ENCODED: [type: :uri, base64: true]
      end

      assert {:ok} = Env1.Encoded.validate()
    end

    test "should return error for all invalid environment variables" do
      defmodule Env2 do
        use Mahaul,
          MOCK__ENV__MISSING: [type: :str],
          MOCK__ENV__NUM: [type: :int],
          MOCK__ENV__INT: [type: :bool],
          MOCK__ENV__BOOL: [type: :num],
          MOCK__ENV__PORT: [type: :host],
          MOCK__ENV__HOST: [type: :uri],
          MOCK__ENV__URI: [type: :int]
      end

      fun = fn ->
        assert {:error,
                "MOCK__ENV__MISSING\nMOCK__ENV__NUM\nMOCK__ENV__INT\nMOCK__ENV__BOOL\nMOCK__ENV__PORT\nMOCK__ENV__HOST\nMOCK__ENV__URI"} =
                 Env2.validate()
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__MISSING\n" <>
                 "MOCK__ENV__NUM\n" <>
                 "MOCK__ENV__INT\n" <>
                 "MOCK__ENV__BOOL\n" <>
                 "MOCK__ENV__PORT\n" <>
                 "MOCK__ENV__HOST\n" <>
                 "MOCK__ENV__URI"
    end

    test "should return error for all invalid encoded environment variables" do
      defmodule Env2.Encoded do
        use Mahaul,
          MOCK__ENV__MISSING_ENCODED: [type: :str, base64: true],
          MOCK__ENV__NUM_ENCODED: [type: :int, base64: true],
          MOCK__ENV__INT_ENCODED: [type: :bool, base64: true],
          MOCK__ENV__BOOL_ENCODED: [type: :num, base64: true],
          MOCK__ENV__PORT_ENCODED: [type: :host, base64: true],
          MOCK__ENV__HOST_ENCODED: [type: :uri, base64: true],
          MOCK__ENV__URI_ENCODED: [type: :int, base64: true]
      end

      fun = fn ->
        assert {:error,
                "MOCK__ENV__MISSING_ENCODED\n" <>
                  "MOCK__ENV__NUM_ENCODED\n" <>
                  "MOCK__ENV__INT_ENCODED\n" <>
                  "MOCK__ENV__BOOL_ENCODED\n" <>
                  "MOCK__ENV__PORT_ENCODED\n" <>
                  "MOCK__ENV__HOST_ENCODED\n" <> "MOCK__ENV__URI_ENCODED"} =
                 Env2.Encoded.validate()
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__MISSING_ENCODED\n" <>
                 "MOCK__ENV__NUM_ENCODED\n" <>
                 "MOCK__ENV__INT_ENCODED\n" <>
                 "MOCK__ENV__BOOL_ENCODED\n" <>
                 "MOCK__ENV__PORT_ENCODED\n" <>
                 "MOCK__ENV__HOST_ENCODED\n" <>
                 "MOCK__ENV__URI_ENCODED"
    end
  end

  describe "validate!/0" do
    test "should not raise exception for valid environment variables" do
      defmodule Env3 do
        use Mahaul,
          MOCK__ENV__STR: [type: :str],
          MOCK__ENV__ENUM: [type: :enum],
          MOCK__ENV__NUM: [type: :num],
          MOCK__ENV__INT: [type: :int],
          MOCK__ENV__BOOL: [type: :bool],
          MOCK__ENV__PORT: [type: :port],
          MOCK__ENV__HOST: [type: :host],
          MOCK__ENV__URI: [type: :uri]
      end

      fun = fn ->
        assert :ok = Env3.validate!()
      end

      capture_log(fun)
    end

    test "should not raise exception for valid encoded environment variables" do
      defmodule Env3.Encoded do
        use Mahaul,
          MOCK__ENV__STR_ENCODED: [type: :str, base64: true],
          MOCK__ENV__ENUM_ENCODED: [type: :enum, base64: true],
          MOCK__ENV__NUM_ENCODED: [type: :num, base64: true],
          MOCK__ENV__INT_ENCODED: [type: :int, base64: true],
          MOCK__ENV__BOOL_ENCODED: [type: :bool, base64: true],
          MOCK__ENV__PORT_ENCODED: [type: :port, base64: true],
          MOCK__ENV__HOST_ENCODED: [type: :host, base64: true],
          MOCK__ENV__URI_ENCODED: [type: :uri, base64: true]
      end

      fun = fn ->
        assert :ok = Env3.Encoded.validate!()
      end

      capture_log(fun)
    end

    test "should raise exception for invalid environment variables" do
      defmodule Env4 do
        use Mahaul,
          MOCK__ENV__MISSING: [type: :str],
          MOCK__ENV__NUM: [type: :int],
          MOCK__ENV__INT: [type: :bool],
          MOCK__ENV__BOOL: [type: :num],
          MOCK__ENV__PORT: [type: :host],
          MOCK__ENV__HOST: [type: :uri],
          MOCK__ENV__URI: [type: :int]
      end

      fun = fn ->
        assert_raise RuntimeError, "Invalid environment variables!", fn ->
          Env4.validate!()
        end
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__MISSING\n" <>
                 "MOCK__ENV__NUM\n" <>
                 "MOCK__ENV__INT\n" <>
                 "MOCK__ENV__BOOL\n" <>
                 "MOCK__ENV__PORT\n" <>
                 "MOCK__ENV__HOST\n" <>
                 "MOCK__ENV__URI"
    end

    test "should raise exception for invalid encoded environment variables" do
      defmodule Env4.Encoded do
        use Mahaul,
          MOCK__ENV__MISSING_ENCODED: [type: :str, base64: true],
          MOCK__ENV__NUM_ENCODED: [type: :int, base64: true],
          MOCK__ENV__INT_ENCODED: [type: :bool, base64: true],
          MOCK__ENV__BOOL_ENCODED: [type: :num, base64: true],
          MOCK__ENV__PORT_ENCODED: [type: :host, base64: true],
          MOCK__ENV__HOST_ENCODED: [type: :uri, base64: true],
          MOCK__ENV__URI_ENCODED: [type: :int, base64: true]
      end

      fun = fn ->
        assert_raise RuntimeError, "Invalid environment variables!", fn ->
          Env4.Encoded.validate!()
        end
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__MISSING_ENCODED\n" <>
                 "MOCK__ENV__NUM_ENCODED\n" <>
                 "MOCK__ENV__INT_ENCODED\n" <>
                 "MOCK__ENV__BOOL_ENCODED\n" <>
                 "MOCK__ENV__PORT_ENCODED\n" <>
                 "MOCK__ENV__HOST_ENCODED\n" <>
                 "MOCK__ENV__URI_ENCODED"
    end
  end

  describe "accessing environment variables" do
    test "should work" do
      defmodule Env5 do
        use Mahaul,
          MOCK__ENV__STR: [type: :str],
          MOCK__ENV__ENUM: [type: :enum],
          MOCK__ENV__NUM: [type: :num],
          MOCK__ENV__INT: [type: :int],
          MOCK__ENV__BOOL: [type: :bool],
          MOCK__ENV__PORT: [type: :port],
          MOCK__ENV__HOST: [type: :host],
          MOCK__ENV__URI: [type: :uri]
      end

      assert "__MOCK__VAL1__" = Env5.mock__env__str()
      assert :__MOCK__VAL2__ = Env5.mock__env__enum()
      assert 10.10 = Env5.mock__env__num()
      assert 10 = Env5.mock__env__int()
      assert true = Env5.mock__env__bool()
      assert 8080 = Env5.mock__env__port()
      assert "//example.com" = Env5.mock__env__host()
      assert "https://example.com/something" = Env5.mock__env__uri()
    end

    test "should work when encoded" do
      defmodule Env5.Encoded do
        use Mahaul,
          MOCK__ENV__STR_ENCODED: [type: :str, base64: true],
          MOCK__ENV__ENUM_ENCODED: [type: :enum, base64: true],
          MOCK__ENV__NUM_ENCODED: [type: :num, base64: true],
          MOCK__ENV__INT_ENCODED: [type: :int, base64: true],
          MOCK__ENV__BOOL_ENCODED: [type: :bool, base64: true],
          MOCK__ENV__PORT_ENCODED: [type: :port, base64: true],
          MOCK__ENV__HOST_ENCODED: [type: :host, base64: true],
          MOCK__ENV__URI_ENCODED: [type: :uri, base64: true]
      end

      assert "__MOCK__VAL1__" = Env5.Encoded.mock__env__str_encoded()
      assert :__MOCK__VAL2__ = Env5.Encoded.mock__env__enum_encoded()
      assert 10.10 = Env5.Encoded.mock__env__num_encoded()
      assert 10 = Env5.Encoded.mock__env__int_encoded()
      assert true = Env5.Encoded.mock__env__bool_encoded()
      assert 8080 = Env5.Encoded.mock__env__port_encoded()
      assert "//example.com" = Env5.Encoded.mock__env__host_encoded()
      assert "https://example.com/something" = Env5.Encoded.mock__env__uri_encoded()
    end

    test "should return default values" do
      defmodule Env6 do
        use Mahaul,
          MOCK__ENV__NEW__STR: [type: :str, default: "VAL1"],
          MOCK__ENV__NEW__ENUM: [type: :enum, default: "VAL2"],
          MOCK__ENV__NEW__NUM: [type: :num, default: "101.11"],
          MOCK__ENV__NEW__INT: [type: :int, default: "9876"],
          MOCK__ENV__NEW__BOOL: [type: :bool, default: "1"],
          MOCK__ENV__NEW__PORT: [type: :port, default: "4000"],
          MOCK__ENV__NEW__HOST: [type: :host, default: "//192.168.0.1"],
          MOCK__ENV__NEW__URI: [type: :uri, default: "ftp://example.com/something"]
      end

      assert "VAL1" = Env6.mock__env__new__str()
      assert :VAL2 = Env6.mock__env__new__enum()
      assert 101.11 = Env6.mock__env__new__num()
      assert 9876 = Env6.mock__env__new__int()
      assert true = Env6.mock__env__new__bool()
      assert 4000 = Env6.mock__env__new__port()
      assert "//192.168.0.1" = Env6.mock__env__new__host()
      assert "ftp://example.com/something" = Env6.mock__env__new__uri()
    end

    test "deprecated: should return default values for prod" do
      Config.Reader.read!("test/support/config/prod.exs")
      |> Application.put_all_env()

      fun = fn ->
        defmodule Env7 do
          use Mahaul,
            MOCK__ENV__NEW__STR: [type: :str, default: "VAL1"],
            MOCK__ENV__NEW__ENUM: [type: :enum, default: "VAL2"],
            MOCK__ENV__NEW__NUM: [type: :num, default: "101.11"],
            MOCK__ENV__NEW__INT: [type: :int, default: "9876"],
            MOCK__ENV__NEW__BOOL: [type: :bool, default: "1"],
            MOCK__ENV__NEW__PORT: [type: :port, default: "4000"],
            MOCK__ENV__NEW__HOST: [type: :host, default: "//192.168.0.1"],
            MOCK__ENV__NEW__URI: [type: :uri, default: "ftp://example.com/something"]
        end

        assert "VAL1" = Env7.mock__env__new__str()
        assert :VAL2 = Env7.mock__env__new__enum()
        assert 101.11 = Env7.mock__env__new__num()
        assert 9876 = Env7.mock__env__new__int()
        assert true = Env7.mock__env__new__bool()
        assert 4000 = Env7.mock__env__new__port()
        assert "//192.168.0.1" = Env7.mock__env__new__host()
        assert "ftp://example.com/something" = Env7.mock__env__new__uri()
      end

      capture_io(:stderr, fun)
    end

    test "deprecated: should return default values for dev" do
      Config.Reader.read!("test/support/config/dev.exs")
      |> Application.put_all_env()

      fun = fn ->
        defmodule Env8 do
          use Mahaul,
            MOCK__ENV__NEW__STR: [type: :str, default_dev: "VAL1"],
            MOCK__ENV__NEW__ENUM: [type: :enum, default_dev: "VAL2"],
            MOCK__ENV__NEW__NUM: [type: :num, default_dev: "101.11"],
            MOCK__ENV__NEW__INT: [type: :int, default_dev: "9876"],
            MOCK__ENV__NEW__BOOL: [type: :bool, default_dev: "1"],
            MOCK__ENV__NEW__PORT: [type: :port, default_dev: "4000"],
            MOCK__ENV__NEW__HOST: [type: :host, default_dev: "//192.168.0.1"],
            MOCK__ENV__NEW__URI: [type: :uri, default_dev: "ftp://example.com/something"]
        end

        assert "VAL1" = Env8.mock__env__new__str()
        assert :VAL2 = Env8.mock__env__new__enum()
        assert 101.11 = Env8.mock__env__new__num()
        assert 9876 = Env8.mock__env__new__int()
        assert true = Env8.mock__env__new__bool()
        assert 4000 = Env8.mock__env__new__port()
        assert "//192.168.0.1" = Env8.mock__env__new__host()
        assert "ftp://example.com/something" = Env8.mock__env__new__uri()
      end

      capture_io(:stderr, fun)
    end

    test "deprecated: should return default values for test" do
      Config.Reader.read!("test/support/config/test.exs")
      |> Application.put_all_env()

      fun = fn ->
        defmodule Env9 do
          use Mahaul,
            MOCK__ENV__NEW__STR: [type: :str, default_dev: "VAL1"],
            MOCK__ENV__NEW__ENUM: [type: :enum, default_dev: "VAL2"],
            MOCK__ENV__NEW__NUM: [type: :num, default_dev: "101.11"],
            MOCK__ENV__NEW__INT: [type: :int, default_dev: "9876"],
            MOCK__ENV__NEW__BOOL: [type: :bool, default_dev: "1"],
            MOCK__ENV__NEW__PORT: [type: :port, default_dev: "4000"],
            MOCK__ENV__NEW__HOST: [type: :host, default_dev: "//192.168.0.1"],
            MOCK__ENV__NEW__URI: [type: :uri, default_dev: "ftp://example.com/something"]
        end

        assert "VAL1" = Env9.mock__env__new__str()
        assert :VAL2 = Env9.mock__env__new__enum()
        assert 101.11 = Env9.mock__env__new__num()
        assert 9876 = Env9.mock__env__new__int()
        assert true = Env9.mock__env__new__bool()
        assert 4000 = Env9.mock__env__new__port()
        assert "//192.168.0.1" = Env9.mock__env__new__host()
        assert "ftp://example.com/something" = Env9.mock__env__new__uri()
      end

      capture_io(:stderr, fun)
    end

    test "deprecated: should return default values with fallback for dev" do
      Config.Reader.read!("test/support/config/dev.exs")
      |> Application.put_all_env()

      fun = fn ->
        defmodule Env10 do
          use Mahaul,
            MOCK__ENV__NEW__STR: [type: :str, default: "VAL1", default_dev: "DEV_VAL1"]
        end

        assert "DEV_VAL1" = Env10.mock__env__new__str()
      end

      capture_io(:stderr, fun)
    end

    test "deprecated: should not return default dev fallback values for prod" do
      Config.Reader.read!("test/support/config/prod.exs")
      |> Application.put_all_env()

      fun = fn ->
        defmodule Env11 do
          use Mahaul,
            MOCK__ENV__NEW__STR: [type: :str, default: "VAL1", default_dev: "DEV_VAL1"]
        end

        assert "VAL1" = Env11.mock__env__new__str()
      end

      capture_io(:stderr, fun)
    end

    test "should return mix environment specific defaults with fallback" do
      Config.Reader.read!("test/support/config/custom.exs")
      |> Application.put_all_env()

      defmodule Env12 do
        use Mahaul,
          MOCK__ENV__STR: [type: :str, default: "VAL1", defaults: [custom: "CUSTOM_VAL"]],
          MOCK__ENV__NEW__STR: [type: :str, default: "VAL1", defaults: [custom: "CUSTOM_VAL"]],
          MOCK__ENV__NEW__STR2: [
            type: :str,
            default: "VAL1",
            defaults: [dev: "DEV_VAL", prod: "PROD_VAL"]
          ]
      end

      assert "__MOCK__VAL1__" = Env12.mock__env__str()
      assert "CUSTOM_VAL" = Env12.mock__env__new__str()
      assert "VAL1" = Env12.mock__env__new__str2()
    end
  end

  describe "choices option" do
    test "should warn for values not in choices list" do
      defmodule Env.Choices1 do
        use Mahaul,
          MOCK__ENV__CHOICES: [type: :int, choices: [1, 2, 3, 4, 5, 6, 7]]
      end

      fun = fn ->
        assert {:error, "MOCK__ENV__CHOICES"} = Env.Choices1.validate()
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__CHOICES"
    end

    test "should throw error for values not in choices list" do
      defmodule Env.Choices2 do
        use Mahaul,
          MOCK__ENV__CHOICES: [type: :int, choices: [1, 2, 3, 4, 5, 6, 7]]
      end

      fun = fn ->
        assert_raise RuntimeError, "Invalid environment variables!", fn ->
          Env.Choices2.validate!()
        end
      end

      assert capture_log(fun) =~
               "missing or invalid environment variables.\n" <>
                 "MOCK__ENV__CHOICES"
    end

    test "should return valid value from the list" do
      defmodule Env.Choices3 do
        use Mahaul,
          MOCK__ENV__CHOICES: [type: :int, default: "7", choices: [1, 2, 3, 4, 5, 6, 7]]
      end

      assert 7 = Env.Choices3.mock__env__choices()
    end
  end

  describe "fun option" do
    test "should define a function with custom name" do
      Config.Reader.read!("test/support/config/custom.exs")
      |> Application.put_all_env()

      defmodule Env.Fun1 do
        use Mahaul,
          MOCK__ENV__STR: [type: :str, fun: :custom_str],
          MOCK__ENV__STR2: [
            type: :str,
            fun: :custom_str2,
            default: "VAL1",
            defaults: [custom: "CUSTOM_VAL"]
          ],
          MOCK__ENV__ENUM: [type: :enum, fun: :custom_enum],
          MOCK__ENV__NUM: [type: :num, fun: :custom_num],
          MOCK__ENV__INT: [type: :int, fun: :custom_int],
          MOCK__ENV__BOOL: [type: :bool, fun: :custom_bool],
          MOCK__ENV__PORT: [type: :port, fun: :custom_port],
          MOCK__ENV__HOST: [type: :host, fun: :custom_host],
          MOCK__ENV__URI: [type: :uri, fun: :custom_uri]
      end

      assert "__MOCK__VAL1__" == Env.Fun1.custom_str()
      assert "CUSTOM_VAL" == Env.Fun1.custom_str2()
      assert :__MOCK__VAL2__ = Env.Fun1.custom_enum()
      assert 10.10 = Env.Fun1.custom_num()
      assert 10 = Env.Fun1.custom_int()
      assert true = Env.Fun1.custom_bool()
      assert 8080 = Env.Fun1.custom_port()
      assert "//example.com" = Env.Fun1.custom_host()
      assert "https://example.com/something" = Env.Fun1.custom_uri()
    end
  end
end
