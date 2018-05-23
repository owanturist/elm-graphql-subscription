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
        , subscribe
        , toCount
        , updateCounter
        )

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value, encode)
import String.Interpolate exposing (interpolate)


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
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , interpolate """
                    mutation CreateCounter {
                        counter: createCounter(count: {0}) {
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
                |> Decode.at [ "data", "counter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


getCounters : Http.Request (List Counter)
getCounters =
    Http.request
        { method = "POST"
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , """
                    query GetCounters {
                        counters: getAllCounters {
                            id
                            count
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
                |> Decode.at [ "data", "counters" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


getCounter : ID { counter : () } -> Http.Request Counter
getCounter (ID coutnerId) =
    Http.request
        { method = "POST"
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , interpolate """
                    query GetCounter {
                        counter: getCounter(id: "{0}") {
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
                |> Decode.at [ "data", "counter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


updateCounter : ID { counter : () } -> List (Field { toCount : () }) -> Http.Request Counter
updateCounter (ID coutnerId) fields =
    Http.request
        { method = "POST"
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , interpolate """
                    mutation UpdateCounter {
                        counter: updateCounter(id: "{0}", payload: {1}) {
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
                |> Decode.at [ "data", "counter" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


deleteCounter : ID { counter : () } -> Http.Request Bool
deleteCounter (ID coutnerId) =
    Http.request
        { method = "POST"
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , interpolate """
                    mutation DeleteCounter {
                        deleted: deleteCounter(id: "{0}")
                    }
                    """
                    [ coutnerId ]
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            Decode.bool
                |> Decode.at [ "data", "deleted" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }


subscribe : Http.Request String
subscribe =
    Http.request
        { method = "POST"
        , headers = []
        , url = "http://localhost:3000/graphql"
        , body =
            [ ( "query"
              , """
                subscription Subscription {
                    changed
                }
                """
                    |> Encode.string
              )
            ]
                |> Encode.object
                |> Http.jsonBody
        , expect =
            Decode.string
                |> Decode.at [ "data", "changed" ]
                |> Http.expectJson
        , timeout = Nothing
        , withCredentials = False
        }
