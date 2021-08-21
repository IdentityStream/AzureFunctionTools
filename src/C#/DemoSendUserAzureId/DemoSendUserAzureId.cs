using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace IdentityStream.ServiceManager.AzureFunctionTools
{
    public static class DemoSendUserAzureId
    {
        [FunctionName("DemoSendUserAzureId")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);
            if  (data == null) {
                return new BadRequestObjectResult("No data");
            }
            string name = data.targetUserName;
            string department = data.targetUserDepartment;
            string azureId = data.targetUserAzureId;
            string profitCenter = data.targetUserDepartmentProfitCenter;
            string managerName = data.managerName;
            string managerAzureId = data.managerAzureId;
            string fromDate = data.fromDate;
            string toDate = data.toDate;

            string responseMessage = $"Brukeren {name} med Azure Id {azureId} i avdelingen {department} ({profitCenter}) fikk registrert fravær fra {fromDate} til {toDate} etter godkjenning fra leder {managerName} som har Azure id {managerAzureId}.";

            return new OkObjectResult(responseMessage);
        }
    }
}
