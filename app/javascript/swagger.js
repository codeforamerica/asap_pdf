import SwaggerUI from "swagger-ui-dist/swagger-ui-bundle"
import "swagger-ui-dist/swagger-ui.css"


const ui = SwaggerUI({
    url: "/api/swagger_doc",
    dom_id: "#swagger-ui",
    deepLinking: true,
    docExpansion: "list",
    defaultModelsExpandDepth: 1,
    defaultModelExpandDepth: 1,
    displayRequestDuration: true,
    showExtensions: true,
    showCommonExtensions: true,
    tryItOutEnabled: false,
    persistAuthorization: true,
    supportedSubmitMethods: []
})

window.ui = ui;