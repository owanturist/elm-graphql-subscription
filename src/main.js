import {
    Main
} from './Main.elm';
import {
    SubscriptionClient
} from 'subscriptions-transport-ws';

const app = Main.fullscreen();

const socket = new SubscriptionClient('ws://localhost:7700/subscriptions', {
    reconnect: true
});

app.ports.send.subscribe(query => {
    socket.request({ query }).subscribe(app.ports.subscribe.send);
});
