const uuid = require('uuid/v1');
const express = require('express');
const { makeExecutableSchema } = require('graphql-tools');
const { graphqlExpress, graphiqlExpress } = require('graphql-server-express');
const { execute, subscribe } = require('graphql');
const { createServer } = require('http');
const { SubscriptionServer } = require('subscriptions-transport-ws');
const { PubSub } = require('graphql-subscriptions');
const bodyParser = require('body-parser');

const pubsub = new PubSub();
const COUNTER_CREATED = 'created';
let dataBase = [];

class Counter {
    constructor(id, count) {
        this.id = id;
        this.count = count;
    }

    setCount(count) {
        this.count = count;

        return this;
    }
}

const typeDefs = `
    type Counter {
        id: ID
        count: Int!
    }

    input ConterPayload {
        count: Int
    }

    type Query {
        getCounter(id: ID!): Counter
        getAllCounters: [Counter!]!
    }

    type Mutation {
        createCounter(count: Int!): Counter!
        updateCounter(id: ID!, payload: ConterPayload): Counter
        deleteCounter(id: ID): Boolean!
    }

    type Subscription {
        counterCreated: Counter!
    }
`;

const resolvers = {
    Query: {
        getCounter: (root, { id }) => {
            for (const counter of dataBase) {
                if (counter.id === id) {
                    return counter;
                }
            }

            throw new Error(`Counter with id "${id}" doesn't exist`);
        },

        getAllCounters: () => {
            return dataBase;
        }
    },

    Mutation: {
        createCounter: (root, { count }) => {
            const newCounter = new Counter(uuid(), count);

            dataBase.unshift(newCounter);

            pubsub.publish(COUNTER_CREATED, { counterCreated : newCounter })

            return newCounter;
        },


        updateCounter: (root, { id, payload }) => {
            for (const counter of dataBase) {
                if (counter.id === id) {
                    return counter.setCount(payload.count);
                }
            }

            throw new Error(`Counter with id "${id}" doesn't exist`);
        },

        deleteCounter: (root, { id }) => {
            const result = [];

            for (const counter of dataBase) {
                if (counter.id !== id) {
                    result.push(counter);
                }
            }

            const deleted = result.length < dataBase.length;

            dataBase = result;

            return deleted;
        }
    },

    Subscription: {
        counterCreated: {
            subscribe: () => pubsub.asyncIterator(COUNTER_CREATED)
        }
    }
};

const schema = makeExecutableSchema({ typeDefs, resolvers });
const PORT = 3000;
const server = express();

server.use("*", (req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With');

    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    } else {
        next();
    }
});

server.use('/graphql', bodyParser.json(), graphqlExpress({
    schema
}));

server.use('/graphiql', graphiqlExpress({
    endpointURL: '/graphql',
    subscriptionsEndpoint: `ws://localhost:${PORT}/subscriptions`
}));

const ws = createServer(server);

ws.listen(PORT, () => {
    console.log(`Running a GraphQL API server at http://localhost:${PORT}/graphql`);

    new SubscriptionServer({
        execute,
        subscribe,
        schema
    }, {
        server: ws,
        path: '/subscriptions'
    })
});
