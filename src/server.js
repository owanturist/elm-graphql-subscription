const express = require('express');
const graphqlHTTP = require('express-graphql')
const { graphql, buildSchema } = require('graphql');
const uuid = require('uuid/v1');

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

const schema = buildSchema(`
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
`);

const rootValue = {
    createCounter: ({ count }) => {
        const counter = new Counter(uuid(), count);

        dataBase.unshift(counter);

        return counter;
    },

    getCounter: ({ id }) => {
        for (const counter of dataBase) {
            if (counter.id === id) {
                return counter;
            }
        }

        throw new Error(`Counter with id "${id}" doesn't exist`);
    },

    getAllCounters: () => {
        return dataBase;
    },

    updateCounter: ({ id, payload }) => {
        for (const counter of dataBase) {
            if (counter.id === id) {
                return counter.setCount(payload.count);
            }
        }

        throw new Error(`Counter with id "${id}" doesn't exist`);
    },

    deleteCounter: ({ id }) => {
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
};

const app = express();

app.use("/graphql", (req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With');

    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    } else {
        next();
    }
});

app.use('/graphql', graphqlHTTP({
    schema,
    rootValue,
    graphiql: true
}))

app.listen('3000');

console.log('Running a GraphQL API server at localhost:3000/graphql');
