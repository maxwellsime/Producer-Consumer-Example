-module(cons).
-compile(export_all).

%Task 1 :: Logger prints msg Str then keeps printing until no msg%
logger() -> logger(0). %Don't have to input a count for the method to work%
logger(Count) ->
    receive
        stop -> stop;
        %Receive string%
        Str ->  %Increment count and print string, restart logger with incremented count%
                io:fwrite("[~p]: ~p~n", [Count, Str]),
                X = Count + 1,
                logger(X)
    end.

%Task 2 :: Consumer asks for data from buffer, messages logger each step%
consumer(Logger, Buffer) -> consumer(Logger, Buffer, 0). %Don't have to input a count for the method to work%
consumer(Logger, Buffer, Count) ->
    %Check if Buffer is empty% 
    Buffer!{isEmptyQ, self()},
    receive
        empty ->    Logger!"C: Buffer empty. I wait.",
                    %Wait for notempty msg%
                    receive notEmpty -> auxConsumer(Logger, Buffer, Count) end;
        notEmpty -> auxConsumer(Logger, Buffer, Count)
    end.
%Task 2 auxiliary method for code reuse%
auxConsumer(Logger, Buffer, Count) ->
    %Increment message count%
    X = Count + 1,
    Logger!"C: Consumer awoke, asking for data",
    Buffer!{getData, self()},
    %Receive data, restart consumer%
    receive
        {data, Msg} ->  Logger!lists:concat(['C: Got Data: #', X, ' = ', Msg]),
                        consumer(Logger, Buffer, X)
    end.

%Task 3 :: Buffer takes data from producer and gives to consumer via recieves%
buffer(MaxSize) -> 
    buffer([], MaxSize, none, none).
%Task 3 method when Bufferdata array is empty%
buffer([], MaxSize, WaitingConsumer, WaitingProducer) -> 
    receive
        %Receive full queue question from Producer%
        {isFullQ, Prod} ->  %Send producer information, recall method%
                            Prod!notFull,
                            buffer([], MaxSize, WaitingConsumer, none);
        %Receive empty queue question from Consumer%
        {isEmptyQ, Cons} -> %Save consumer information, check producer, recall method%
                            Cons!empty,
                            pBuffer([], MaxSize, Cons, WaitingProducer);
        %Receive data from Producer%
        {data, Msg} ->      %Add data from msg to BufferData, check consumer, delete WaitingProducer%
                            cBuffer([Msg], MaxSize, WaitingConsumer, WaitingProducer) 
    end;
%Task 3 method when BufferData is not empty%
buffer([B|Bt], MaxSize, WaitingConsumer, WaitingProducer) ->
    %Check size of array, send appropriate information%
    receive
        %Receive full queue question from Producer%
        {isFullQ, Prod} ->  %Send producer info depending on BufferData length, check consumer, recall method%
                            L = length([B|Bt]),
                            case L of
                                %Buffer is full%
                                MaxSize ->  Prod!full,
                                            cBuffer([B|Bt], MaxSize, WaitingConsumer, Prod);
                                %Buffer is not full%
                                _ ->        Prod!notFull,
                                            cBuffer([B|Bt], MaxSize, WaitingConsumer, none)
                            end;
        %Receive empty queue question from Consumer%
        {isEmptyQ, Cons} -> %Send producer info, check and recall method%
                            Cons!notEmpty,
                            pBuffer([B|Bt], MaxSize, none, WaitingProducer);
        %Receive data from Producer%
        {data, Msg} ->      %Add data from msg to BufferData, check consumer, delete WaitingProducer%
                            BufferData = [B|Bt] ++ [Msg],
                            cBuffer(BufferData, MaxSize, WaitingConsumer, none);
        %Receive data request from Consumer%
        {getData, Cons} ->  %Send data to Consumer, check producer, delete WaitingConsumer%
                            Cons!{data, B},
                            if
                                WaitingProducer /= none ->  WaitingProducer!notEmpty,
                                                            buffer(Bt, MaxSize, none, none);
                                true ->                     buffer(Bt, MaxSize, none, none)
                            end
    end.
%Task 3 aux consumer test%
cBuffer(BufferData, MaxSize, WaitingConsumer, WaitingProducer) ->
    if
        WaitingConsumer /= none ->  WaitingConsumer!notEmpty,
                                    buffer(BufferData, MaxSize, none, WaitingProducer);
        true ->                     buffer(BufferData, MaxSize, none, WaitingProducer)
    end.
%Task 3 aux producer test%
pBuffer(BufferData, MaxSize, WaitingConsumer, WaitingProducer) ->
    if
        WaitingProducer /= none ->  WaitingProducer!notFull,
                                    buffer(BufferData, MaxSize, WaitingConsumer, WaitingProducer);
        true ->                     buffer(BufferData, MaxSize, WaitingConsumer, none)
    end.

%Task 4 :: Main tests program, spawns buffer and logger for use in spawned consumer and producer%
main() ->
    Buffer = spawn(?MODULE, buffer, [5]),
    Logger = spawn(?MODULE, logger, []),
    C = spawn(?MODULE, consumer, [Logger, Buffer]),
    P = spawn(producer, producer, [5,Logger, Buffer]).
