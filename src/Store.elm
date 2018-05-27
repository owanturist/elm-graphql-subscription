module Store
    exposing
        ( Counter
        , Field
        , ID
        , createCounter
        , deleteCounter
        , extractID
        , getCounter
        , getCounters
        , toCount
        , updateCounter
        )

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value, encode)
import String.Interpolate exposing (interpolate)


endpoint : String
endpoint =
    "https://p2z4whm3sre3bos2wnucgd2stq.appsync-api.eu-west-1.amazonaws.com/graphql"


headers : List Http.Header
headers =
    [ Http.header "X-Api-Key" "da2-s6xhkxeykbdqjeu6qjwb24n4uy"
    ]


type ID supported
    = ID String


type Field supported
    = Field String Value


fieldsToPayload : List (Field supported) -> String
fieldsToPayload fields =
    let
        fragments =
            List.map (\(Field key value) -> key ++ ":" ++ encode 0 value) fields
    in
    "{" ++ String.join "," fragments ++ "}"


toCount : Int -> Field { supported | toCount : () }
toCount =
    Field "count" << Encode.int


extractID : ID supported -> String
extractID (ID id) =
    id


idDecoder : Decoder (ID supported)
idDecoder =
    Decode.map ID Decode.string


type alias Counter =
    { id : ID { counter : () }
    , count : Int
    }


counterDecoder : Decoder Counter
counterDecoder =
    Decode.map2 Counter
        (Decode.field "id" idDecoder)
        (Decode.field "count" Decode.int)


createCounter : Int -> Http.Request Counter
createCounter count =
    Http.request
        { method = "POST"
        , headers = headers
        , url = endpoint
        , body =
            [ ( "query"
              , interpolate """
                    mutation CreateCounter {
                        createCounter(count: {0}) {
                            id
                            count
                        }
                    }
                    """
                    [ toString count ]
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            counterDecoder
                |> Decode.at [ "data", "createCounter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


getCounters : Http.Request (List Counter)
getCounters =
    Http.request
        { method = "POST"
        , headers = headers
        , url = endpoint
        , body =
            [ ( "query"
              , """
                    query ListCounters {
                        listCounters {
                            items {
                                id
                                count
                            }
                        }
                    }
                    """
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            Decode.list counterDecoder
                |> Decode.at [ "data", "listCounters", "items" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


getCounter : ID { counter : () } -> Http.Request Counter
getCounter (ID coutnerId) =
    Http.request
        { method = "POST"
        , headers = headers
        , url = endpoint
        , body =
            [ ( "query"
              , interpolate """
                    query GetCounter {
                        getCounter(id: "{0}") {
                            id
                            count
                        }
                    }
                    """
                    [ coutnerId ]
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            counterDecoder
                |> Decode.at [ "data", "getCounter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


updateCounter : ID { counter : () } -> List (Field { toCount : () }) -> Http.Request Counter
updateCounter (ID coutnerId) fields =
    Http.request
        { method = "POST"
        , headers = headers
        , url = endpoint
        , body =
            [ ( "query"
              , interpolate """
                    mutation UpdateCounter {
                        updateCounter(id: "{0}", input: {1}) {
                            id
                            count
                        }
                    }
                    """
                    [ coutnerId, fieldsToPayload fields ]
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            counterDecoder
                |> Decode.at [ "data", "updateCounter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


deleteCounter : ID { counter : () } -> Http.Request ()
deleteCounter (ID coutnerId) =
    Http.request
        { method = "POST"
        , headers = headers
        , url = endpoint
        , body =
            [ ( "query"
              , interpolate """
                    mutation DeleteCounter {
                        deleteCounter(id: "{0}") {
                            id
                            count
                        }
                    }
                    """
                    [ coutnerId ]
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            Decode.succeed ()
                |> Decode.at [ "data", "deleteCounter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }
