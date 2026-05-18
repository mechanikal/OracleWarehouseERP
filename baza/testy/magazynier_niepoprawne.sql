BEGIN
    DBMS_OUTPUT.PUT_LINE('--- TEST BŁĘDÓW: MAGAZYNIER ---');
    pkg_magazynier.usun_pole_magazynowe(-12345);
END;
/
