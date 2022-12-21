module djsonrpc2.JSONRPC2Node;

import std.json;

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

        // called on all new notifications (requests without id)
        void delegate(Request req) nothrow onNotification;

        // JSONRPC2Node calls this on new response if no ResponseReceiver designated with
        // sendRequest()
        void delegate() nothrow onResponseNoReceiver;

        // called on all recieved responses
        void delegate() nothrow onResponse;

        // this is called when JSONRPC2Node needs to send message to other side.
        // if this delegate not specified when it's needed - this leads to exception.
        // TODO: probably add this to this() to force it's defenition
        void delegate(string value) nothrow pushMessageToOutside;
    }

    private
    {
        bool closed;
    }

    this()
    {
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
        // }
    }

    // push message from outside to user 
    // (any message, includingly notifications and responses).
    // 'value' must be UTF-8 plain text string with JSON in to, acceptable
    // to be parsed with std.json. this function doesn't do any cleanups or
    // preperations to 'value' before actual use.
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
    void sendRequest(Request req, JSONRPC2NodeResponseReceiver rr, bool genid = false)
    {
        auto rrw = new JSONRPC2NodeResponseReceiverWrapper();
        rrw.rr = rr;
    }
}

private class JSONRPC2NodeResponseReceiverWrapper
{
    JSONValue id;
    JSONRPC2NodeResponseReceiver rr;
}

class JSONRPC2NodeResponseReceiver
{
    void delegate() onClosed;
    void delegate(Request req, Response resp) onResponsed;
}
