const httpSignature = require("http-signature");
const httpDigest = require("@digitalbazaar/http-digest-header");

async function isRequestSignatureValid(request, secret) {
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
  if (!httpSignature.verifyHMAC(parsed, secret)) {
    console.log("Rejected signature");
    return false;
  }
  console.log("Accepted signature");
  return true;
}

module.exports = async function (context, req) {
  context.log("JavaScript HTTP trigger function processed a request.");
  //For development, this needs to be in local.settings.json. See: https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-node?tabs=v2#environment-variables
  const secret = process.env["secret"];
  if (!(await isRequestSignatureValid(context.req, secret))) {
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
