import {
    AWSAppSyncClient
} from 'aws-appsync'
import {
    AUTH_TYPE
} from 'aws-appsync/lib/link/auth-link'
import gql from 'graphql-tag';
import {
    Main
} from './Main.elm';

const app = Main.fullscreen();
const client = new AWSAppSyncClient({
    url: "https://p2z4whm3sre3bos2wnucgd2stq.appsync-api.eu-west-1.amazonaws.com/graphql",
    region: 'eu-west-1',
    auth: {
        type: AUTH_TYPE.API_KEY,
        apiKey: "da2-s6xhkxeykbdqjeu6qjwb24n4uy"
    }
});

app.ports.send.subscribe(query => {
    client
        .subscribe({ query: gql(query) })
        .subscribe({
            next: app.ports.subscribe.send,
            error: err => {
                console.err(err);
            }
        });
});

