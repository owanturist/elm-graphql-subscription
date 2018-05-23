'use strict';

const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');


module.exports = {
    entry: path.resolve('./src/main.js'),

    output: {
        path: path.resolve('./build'),
        filename: '[name].[hash].js'
    },

    resolve: {
        extensions: [ '.js' ]
    },

    module: {
        noParse: /\.elm$/,
        rules: [
            {
                test: /\.elm$/,
                exclude: [
                    /elm-stuff/,
                    /node_modules/
                ],
                use: 'elm-webpack-loader'
            }
        ]
    },

    devServer: {
        historyApiFallback: true
    },

    plugins: [
        new HtmlWebpackPlugin({
            template: path.resolve('./src/index.html'),
            inject: 'body',
            filename: 'index.html'
        })
    ],

    devtool: 'eval-source-map',
    mode: 'development'
};
