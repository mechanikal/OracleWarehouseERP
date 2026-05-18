DECLARE
    v_cursor SYS_REFCURSOR;
    v_id NUMBER;
    v_typ VARCHAR2(20);
    v_nazwa VARCHAR2(100);
    v_data DATE;
    v_id_pola_do_usuniecia NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== MAGAZYNIER: INWENTARYZACJA ===');

    pkg_magazynier.wyswietl_stan_magazynu;

    pkg_magazynier.raport_przeterminowane(v_cursor);
    LOOP
        FETCH v_cursor INTO v_id, v_typ, v_nazwa, v_data;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('! PRZETERMINOWANE ! Pole: ' || v_id || ' | ' || v_nazwa);
    END LOOP;
    CLOSE v_cursor;

    SELECT id_pola INTO v_id_pola_do_usuniecia 
    FROM TABLE(SELECT m.pola FROM magazyn m) 
    WHERE czy_surowiec = 1 AND ROWNUM = 1;

    pkg_magazynier.usun_pole_magazynowe(v_id_pola_do_usuniecia);
    
    DBMS_OUTPUT.PUT_LINE('=== KONIEC DZIAŁAŃ MAGAZYNIERA ===');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Magazyn jest pusty, nie ma czego usuwać.');
END;
/
