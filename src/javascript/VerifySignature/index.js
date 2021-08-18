const httpSignature = require("http-signature");
const httpDigest = require("@digitalbazaar/http-digest-header");

async function isRequestSignatureValid(request) {
  var cloned = JSON.parse(JSON.stringify(request));
  cloned.method = "post";
  const url = new URL(cloned.originalUrl);
  cloned.url = url.pathname + url.search;
  //check digest
  var digestVerified = (
    await httpDigest.verifyHeaderValue({
      data: cloned.rawBody,
      headerValue: cloned.headers.digest,
    })
  ).verified;
  if (!digestVerified) {
    console.log("Rejected digest");
    return false;
  } else {
    console.log("accepted digest");
  }
  var parsed = httpSignature.parseRequest(cloned);
  if (
    !httpSignature.verifyHMAC(parsed, "42e88981-05a9-4e60-8d39-31737447e30b")
  ) {
    console.log("Rejected signature");
    return false;
  }
  console.log("Accepted signature");
  return true;
}

module.exports = async function (context, req) {
  context.log("JavaScript HTTP trigger function processed a request.");
  if (!(await isRequestSignatureValid(context.req))) {
    context.res = {
      status: 401,
    };
    return;
  }
  const name = req.query.name || (req.body && req.body.name);
  const responseMessage = name
    ? "Hello, " + name + ". This HTTP triggered function executed successfully."
    : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";

  context.res = {
    // status: 200, /* Defaults to 200 */
    body: responseMessage,
  };
};
