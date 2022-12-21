module djsonrpc2.protocol;

import std.json;
import std.typecons;

import dlgo;

debug import std.stdio;

// gerror != null -> not ok

nothrow:

private gerror checkJSONRPC2field(JSONValue val)
{
    try
    {
        if (!("jsonrpc" in val))
        {
            return new gerror("no 'jsonrpc' key in val");
        }

        if (val["jsonrpc"].type != JSONType.string)
        {
            return new gerror("'jsonrpc' key has invalid data type");
        }

        if (val["jsonrpc"].str != "2.0")
        {
            return new gerror("invalid 'jsonrpc' version");
        }
    }
    catch (gerror e)
    {
        return e;
    }
    return cast(gerror) null;
}

private class Ided
{
    private
    {
        JSONValue _id;
    }

    bool haveId()
    {
        return _id.type != JSONType.null_;
    }

    void delId()
    {
        _id = JSONValue(null);
    }

    JSONValue id()
    {
        return _id;
    }

    // passing value of type null - removes 'id' from Request
    gerror id(JSONValue value)
    {
        switch (value.type)
        {
        case JSONType.string:
        case JSONType.integer:
        case JSONType.uinteger:
            _id = value;
            break;
        case JSONType.null_:
            delId();
            break;
        default:
            return new gerror("invalid value type for 'id'");
        }
        return cast(gerror) null;
    }
}

class Request : Ided
{
    private
    {
        string _method;
        JSONValue _params;
    }

    static Tuple!(Request, gerror) newFromString(string val, bool check_jsonrpc_key = true)
    {
        auto parsed = parseJSON(val);
        return newFromJSONValue(parsed, check_jsonrpc_key);
    }

    static Tuple!(Request, gerror) newFromJSONValue(JSONValue val, bool check_jsonrpc_key = true)
    {
        if (check_jsonrpc_key)
        {
            auto err = checkJSONRPC2field(val);
            if (err !is null)
            {
                return tuple(cast(Request) null, err);
            }
        }

        auto ret = new Request();

        if ("id" in val)
        {
            auto err = ret.id(val["id"]);
            if (err !is null)
            {
                return tuple(cast(Request) null, err);
            }
        }

        if ("method" in val)
        {
            if (val["method"].type != JSONType.string)
            {
                return tuple(cast(Request) null, new Exception("invalid 'method' data type"));
            }
            ret.method(val["method"].str());
        }

        if ("params" in val)
        {
            ret.params(val["params"]);
        }

        return tuple(ret, cast(gerror) null);
    }

    string method()
    {
        return _method;
    }

    void method(string value)
    {
        _method = value;
    }

    JSONValue params()
    {
        return _params;
    }

    void params(JSONValue value)
    {
        _params = value;
    }

    JSONValue toJSONValue()
    {
        JSONValue ret;
        ret["jsonrpc"] = "2.0";
        if (haveId())
            ret["id"] = id();
        ret["method"] = method();
        ret["params"] = params();
        return ret;
    }
}

class Response : Ided
{
    private
    {
        JSONValue _result;
        JSONRPC2Error _error;
    }

    static Tuple!(Response, gerror) newFromString(string val, bool check_jsonrpc_key = true)
    {
        auto parsed = parseJSON(val);
        return newFromJSONValue(parsed, check_jsonrpc_key);
    }

    static Tuple!(Response, gerror) newFromJSONValue(JSONValue val, bool check_jsonrpc_key = true)
    {
        if (check_jsonrpc_key)
        {
            auto err = checkJSONRPC2field(val);
            if (err !is null)
            {
                return tuple(cast(Response) null, err);
            }
        }

        auto ret = new Response();

        if ("id" in val)
        {
            auto err = ret.id(val["id"]);
            if (err !is null)
            {
                return tuple(cast(Response) null, err);
            }
        }

        if ("error" in val)
        {
            auto res = JSONRPC2Error.newFromJSONValue(val["error"]);
            if (res[1]!is null)
            {
                return tuple(cast(Response) null, res[1]);
            }
            ret.error(res[0]);
        }
        else if ("result" in val)
        {
            ret.result(val["result"]);
        }
        else
        {
            return tuple(cast(Response) null,
                    new gerror("invalid response structure: no error and no result"));
        }

        return tuple(ret, cast(gerror) null);
    }

    void result(JSONValue value)
    {
        _error = null;
        _result = value;
    }

    JSONValue result()
    {
        return _result;
    }

    // NOTE: passing null - deletes error from Respone, so if result is not set, response becomes invalid
    void error(JSONRPC2Error value)
    {
        _error = value;
        // delete result if error is not null
        if (value !is null)
            _result = JSONValue();
    }

    JSONRPC2Error error()
    {
        return _error;
    }

    JSONValue toJSONValue()
    {
        JSONValue ret;
        ret["jsonrpc"] = "2.0";
        if (haveId())
            ret["id"] = id();
        if (error is null)
            ret["result"] = result();
        else
            ret["error"] = error().toJSONValue();
        return ret;
    }
}

class JSONRPC2Error
{
    private
    {
        int _code;
        string _message;
        bool _haveData;
        JSONValue _data;
    }

    static Tuple!(JSONRPC2Error, gerror) newFromJSONValue(JSONValue value)
    {
        auto ret = new JSONRPC2Error();

        if ("code" !in value)
        {
            return tuple(cast(JSONRPC2Error) null,
                    new gerror("no 'code' field found in error structure"));
        }

        switch (value["code"].type)
        {
        case JSONType.integer:
        case JSONType.uinteger:
            break;
        default:
            return tuple(cast(JSONRPC2Error) null,
                    new gerror("invalid error structure: 'code' type invalid"));
        }

        ret.code(cast(int)(value["code"].integer));

        if ("message" in value)
        {
            ret.message(value["message"].str);
        }

        if ("data" in value)
        {
            ret.data(value["data"]);
        }

        return tuple(ret, cast(gerror) null);
    }

    static JSONRPC2Error newByCode(int value, bool auto_message = false)
    {
        auto ret = new JSONRPC2Error();
        ret.code(value, auto_message);
        return ret;
    }

    static JSONRPC2Error newByCodeAndMessage(int value, string message)
    {
        auto ret = new JSONRPC2Error();
        ret.code(value);
        ret.message(message);
        return ret;
    }

    // static const JSONRPC2Error ErrParseError = new JSONRPC2Error(-32700, "Parse error");

    static JSONRPC2Error newParseError()
    {
        return newByCode(-32700);
    }

    static JSONRPC2Error newInvalidRequest()
    {
        return newByCode(-32600);
    }

    static JSONRPC2Error newMethodNotFound()
    {
        return newByCode(-32601);
    }

    static JSONRPC2Error newInvalidParams()
    {
        return newByCode(-32602);
    }

    static JSONRPC2Error newInternalError()
    {
        return newByCode(-32603);
    }

    // value >= -32000 && value <= -32099
    static Tuple!(JSONRPC2Error, gerror) newServerError(int value)
    {
        if (value >= -32000 && value <= -32099)
            return tuple(newByCodeAndMessage(value, "Server error"), cast(gerror) null);
        else
            return tuple(cast(JSONRPC2Error) null,
                    new gerror("invalid code for 'Server error' error type"));
    }

    void code(int value, bool auto_message = false)
    {
        _code = value;

        if (auto_message) switch (value)
        {
        case -32700:
            _message = "Parse error";
            break;
        case -32600:
            _message = "Invalid Request";
            break;
        case -32601:
            _message = "Method not found";
            break;
        case -32602:
            _message = "Invalid params";
            break;
        case -32603:
            _message = "Internal error";
            break;
        default:
            if (value >= -32000 && value <= -32099)
                _message = "Server error";
        }
    }

    int code()
    {
        return _code;
    }

    void message(string value)
    {
        _message = value;
    }

    string message()
    {
        return _message;
    }

    void data(JSONValue value)
    {
        _haveData = true;
        _data = value;
    }

    JSONValue data()
    {
        return _data;
    }

    bool haveData()
    {
        return _haveData;
    }

    void delData()
    {
        _haveData = false;
        _data = JSONValue();
    }

    JSONValue toJSONValue()
    {
        JSONValue ret;
        ret["code"] = code();
        ret["message"] = message();
        if (_haveData)
            ret["data"] = data();
        return ret;
    }
}
