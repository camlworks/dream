import React from "react";
import {createRoot} from "react-dom/client";
import {GraphiQL} from "graphiql";
import {createTransport} from "@graphiql/toolkit";
import {createClient} from "graphql-ws";
import "graphiql/style.css";

const endpoint = "%%ENDPOINT%%";
const defaultQuery = "%%DEFAULT_QUERY%%";

const wsSchema = location.protocol === "https:" ? "wss:" : "ws:";
const wsEndpoint = wsSchema + "//" + window.location.host + endpoint;

const transport = createTransport({
  url: endpoint,
  // Dream's GraphQL handler does not support GraphQL-over-HTTP GET or OPTIONS
  supportedMethods: ["POST"],
  subscriptionClient: createClient({url: wsEndpoint}),
});

createRoot(document.getElementById("graphiql")).render(
  React.createElement(GraphiQL, {
    transport,
    defaultQuery,
    defaultEditorToolsVisibility: true,
  })
);
