SET SERVEROUTPUT ON;
DECLARE
    v_count       NUMBER;
    v_prev_count  NUMBER := -1;
    v_sql         VARCHAR2(200);
    v_dropped_cnt NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ROZPOCZYNAM TOTALNE CZYSZCZENIE SCHEMATU ===');

    -- Pętla działa dopóki są obiekty I dopóki udaje nam się coś usuwać
    LOOP
        -- Sprawdź ile obiektów zostało (pomijamy te, których nie można usunąć bezpośrednio jak INDEX PARTITION, LOB itp, bo one znikną z tabelami)
        SELECT COUNT(*) INTO v_count 
        FROM user_objects 
        WHERE object_type NOT IN ('INDEX', 'LOB', 'TABLE PARTITION', 'TRIGGER', 'PACKAGE BODY'); 
        
        -- Wyjście, jeśli pusto
        IF v_count = 0 THEN
            EXIT;
        END IF;

        -- Zabezpieczenie przed nieskończoną pętlą (jeśli nic nie ubywa)
        IF v_count = v_prev_count THEN
            DBMS_OUTPUT.PUT_LINE('!!! UWAGA: Liczba obiektów przestała spadać. Coś blokuje usuwanie.');
            EXIT;
        END IF;
        v_prev_count := v_count;

        DBMS_OUTPUT.PUT_LINE('Znaleziono obiektów do usunięcia: ' || v_count || '. Rozpoczynam przebieg...');

        -- 1. TABELE (Kluczowe: CASCADE CONSTRAINTS PURGE usuwa też indeksy i triggery)
        FOR r IN (SELECT table_name FROM user_tables) LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP TABLE "' || r.table_name || '" CASCADE CONSTRAINTS PURGE';
                DBMS_OUTPUT.PUT_LINE(' -> Usunięto tabelę: ' || r.table_name);
                v_dropped_cnt := v_dropped_cnt + 1;
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;

        -- 2. WIDOKI
        FOR r IN (SELECT view_name FROM user_views) LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP VIEW "' || r.view_name || '" CASCADE CONSTRAINTS';
                DBMS_OUTPUT.PUT_LINE(' -> Usunięto widok: ' || r.view_name);
                v_dropped_cnt := v_dropped_cnt + 1;
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;

        -- 3. PROCEDURY / FUNKCJE / PAKIETY
        FOR r IN (SELECT object_name, object_type FROM user_objects WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE')) LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' "' || r.object_name || '"';
                DBMS_OUTPUT.PUT_LINE(' -> Usunięto kod: ' || r.object_name);
                v_dropped_cnt := v_dropped_cnt + 1;
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;

        -- 4. SEKWENCJE
        FOR r IN (SELECT sequence_name FROM user_sequences) LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP SEQUENCE "' || r.sequence_name || '"';
                DBMS_OUTPUT.PUT_LINE(' -> Usunięto sekwencję: ' || r.sequence_name);
                v_dropped_cnt := v_dropped_cnt + 1;
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;

        -- 5. TYPY (Z FORCE - usuwa zależności)
        FOR r IN (SELECT type_name FROM user_types) LOOP
            BEGIN
                EXECUTE IMMEDIATE 'DROP TYPE "' || r.type_name || '" FORCE';
                DBMS_OUTPUT.PUT_LINE(' -> Usunięto typ: ' || r.type_name);
                v_dropped_cnt := v_dropped_cnt + 1;
            EXCEPTION WHEN OTHERS THEN NULL; END;
        END LOOP;
        
    END LOOP;

    -- Ostateczne czyszczenie kosza
    EXECUTE IMMEDIATE 'PURGE RECYCLEBIN';

    DBMS_OUTPUT.PUT_LINE('=== KONIEC. Pozostałe obiekty: ===');
    
    -- Raport końcowy - co zostało?
    FOR r IN (SELECT object_type, object_name FROM user_objects ORDER BY object_type) LOOP
        DBMS_OUTPUT.PUT_LINE('POZOSTAŁO: [' || r.object_type || '] ' || r.object_name);
    END LOOP;
    
    IF v_dropped_cnt > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Łącznie usunięto operacji: ' || v_dropped_cnt);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Schemat był już czysty.');
    END IF;
END;
/

DROP TABLE SUROWCE_MLECZARSKIE CASCADE CONSTRAINTS PURGE;
DROP TABLE WARTOSCI_ODZYWCZE CASCADE CONSTRAINTS PURGE;
DROP TABLE RODZAJE_PRODUKTOW CASCADE CONSTRAINTS PURGE;
DROP TABLE TAB_POLA_MAGAZYNOWE CASCADE CONSTRAINTS PURGE;
DROP TABLE TABELA_SKLADNIKOW_PRODUKTU CASCADE CONSTRAINTS PURGE;
DROP TABLE PRODUKTY CASCADE CONSTRAINTS PURGE;
DROP TABLE PARTIE_PRODUKTOW CASCADE CONSTRAINTS PURGE;
DROP TABLE MAGAZYN CASCADE CONSTRAINTS PURGE;
DROP TABLE KONTRAKTY CASCADE CONSTRAINTS PURGE;
DROP TABLE KONTRAHENCI CASCADE CONSTRAINTS PURGE;
DROP TABLE DOSTAWY CASCADE CONSTRAINTS PURGE;
DROP TABLE RODZAJE_SUROWCOW CASCADE CONSTRAINTS PURGE;

SELECT object_name, object_type, status 
FROM user_objects 
ORDER BY object_type, object_name;
