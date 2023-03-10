module djsonrpc2.JSONRPC2Node;

import std.json;
import std.uuid;
import std.datetime;

import core.sync.mutex;

import dlgo;

import dutils.Worker001;

import djsonrpc2.protocol;

nothrow:

// TERMS:
//    user - software, which using JSONRPC2Node to communicate with json-rpc 2.0.
//    outside - network or some other mechanism or transport for raw 
//       or plain text data.

// this implementation supposed to be easy and swift, so 'observable' and it's
// signals not used intentionally.

class JSONRPC2Node
{

    public
    {
        // JSONRPC2Node calls this on new request, receives all request, 
        // including notifications
        Response delegate(Request req) nothrow onRequest;

        // this is called when JSONRPC2Node needs to send message to other side.
        // if this delegate not specified when it's needed - this leads to exception.
        // TODO: probably add this to this() to force it's defenition
        gerror delegate(string value) nothrow pushMessageToOutside;
    }

    public
    {
        Duration defaultResponseWaitTimeout = dur!"minutes"(1);
        // Duration maximumResponseWaitTimeout = dur!"hours"(1);
    }

    private
    {
        bool closed;
        JSONRPC2NodeResponseReceiverWrapper[] respWaiters;
        Mutex respWaiters_lock;
        Worker001 worker;
    }

    this()
    {
        respWaiters_lock = new Mutex();
        worker = new Worker(&respWaitersTimeoutChecker);
    }

    void respWaitersTimeoutChecker(void delegate() set_starting, void delegate() set_working,
            void delegate() set_stopping, void delegate() set_stopped, bool delegate() is_stop_flag)
    {
        set_starting();
        scope (exit)
        {
            set_stopped();
        }

        set_working();
        while (true)
        {
            if (is_stop_flag())
            {
                break;
            }

            if (closed)
            {
                break;
            }

            Thread.sleep(dur!"seconds"(1));
        }
        set_stopping();

        close();
    }

    // helper function to disconnect all waiters.
    // also this sets JSONRPC2Node into closd state, in which pushMessage() throws exception.
    // also it closes (if) any JSONRPC2Node's worker threads.
    void close()
    {
        // TODO: add syncronization
        // synchronized (closed)
        // {
        closed = true;
        worker.stop();
        // }
    }

    // push message from outside to user 
    // (any message, includingly notifications and responses).
    // 'value' must be UTF-8 plain text string with JSON in to, acceptable
    // to be parsed with std.json. this function doesn't do any cleanups or
    // preperations to 'value' before actual use.

    // if onRequest not defined - this throws Exception
    void pushMessageFromOutside(string value)
    {
        // TODO: add syncronization
        // synchronized (closed)
        // {
        if (closed)
        {
            throw new Exception("JSONRPC2Node is closed");
        }
        // }

        auto parsed = parseJSON(value);

        if ("method" in parsed)
        {
            auto res = Request.newFromJSONValue(parsed, true);
            if (res[1]!is null)
            {
                // TODO: error handeling
                return;
            }
            workOnIncommingRequest(res[0]);
            return;
        }
        else
        {
            auto res = Response.newFromJSONValue(parsed, true);
            if (res[1]!is null)
            {
                // TODO: error handeling
                return;
            }
            workOnIncommingResponse(res[0]);
            return;
        }
    }

    private void workOnIncommingRequest(Request value)
    {

    }

    private void workOnIncommingResponse(Response value)
    {

    }

    // send request or notification. to send notification - do not set 'id' in Request.
    // also JSONRPC2Node allows id value == JSON's null, for notifications.

    // notification requests - ignores and doesn't uses passed 'rr'.
    // requests which requres response (requests with 'id') MUST pass rr instance

    // this sendRequest variant returns at once. response will be passed to 'rr' instance.

    // set genid to true, if you wish sendRequest automatically generate unique id. 
    // this also modifies req's id. this guaranties what no same id is already registered
    // within JSONRPC2Node.

    // ids generated with genid is uuid4

    // req's id must be unique for JSONRPC2Node instance, keep this in mind.

    // Exception will be thrown if req's id isn't unique for JSONRPC2Node instance.
    gerror sendRequest(Request req, JSONRPC2NodeResponseReceiver rr,
            bool genid = false, Duration timeout = dur!"minutes"(1))
    {
        if (pushMessageToOutside is null)
        {
            return new gerror("pushMessageToOutside is null");
        }

        if (timeout < dur!"seconds"(0))
        {
            return new gerror("timeout must be not negative");
        }

        if (rr !is null && !req.haveId())
        {
            // TODO: maybe this should be allowd and rr should be simply ignored
            return new gerror("rr defined, but req have no Id");
        }

        auto rrw = new JSONRPC2NodeResponseReceiverWrapper();

        rrw.rr = rr;
        rrw.timeout = timeout;

        gerror err = storeRRW(req, rrw, genid);
        if (err !is null)
        {
            return err;
        }

        auto jv = req.toJSONValue();
        string req_json = jv.toJSON();
        err = pushMessageToOutside(req_json);
        return err;
    }

    private gerror storeRRW(Request req, JSONRPC2NodeResponseReceiverWrapper rrw, bool genid = false)
    {
        synchronized (respWaiters_lock)
        {
            if (genid)
            {
                auto id = genUniqueUUID();
                rrw.id = id;
                req.id(id);
            }
            else
            {
                if (isRegisteredID(req.id))
                {
                    return new gerror("req.id already registered");
                }
                rrw.id = req.id();
            }
            respWaiters ~= rrw;


            synchronized
            {
                if (worker.getStatus() == WorkerStarus.stopped)
                {
                    worker.start();
                }
            }

            return cast(gerror) null;
        }
    }

    private bool isRegisteredID(JSONValue id)
    {
        if (id.type != JSONType.string)
            return false;

        foreach (x; respWaiters)
        {
            if (x.id == id)
                return true;
        }

        return false;
    }

    private JSONValue genUniqueUUID()
    {
        JSONValue ret;
        while (true)
        {
            ret = JSONValue(randomUUID().toString());
            auto res = isRegisteredID(ret);
            if (!res)
                break;
        }
        return ret;
    }
}

private class JSONRPC2NodeResponseReceiverWrapper
{
    JSONValue id;
    Duration timeout;
    JSONRPC2NodeResponseReceiver rr;
}

class JSONRPC2NodeResponseReceiver
{
    void delegate() onNodeClose;
    void delegate() onResponseTimeout;
    void delegate(Request req, Response resp) onResponse;
}
