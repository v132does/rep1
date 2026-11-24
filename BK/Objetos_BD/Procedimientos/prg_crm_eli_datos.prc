CREATE OR REPLACE PROCEDURE IT.PRG_CRM_ELI_DATOS IS
  v_error  varchar2(3000);
  CURSOR TABLAS IS
        Select A.VAL_MINIMO tabla 
          From BA_COD_REFERENCIAS A
          WHERE A.DOMINIO    = 'CRM_TABLAS'
            AND NVL(A.VAL_MAXIMO,'N') = 'S';
BEGIN
     For i in Tablas Loop
         sql_util.ejecute_dml('truncate table '||i.tabla, v_error);
     End Loop;
EXCEPTION
     When Others Then
          raise_application_error(-20000,'Error en PRG_CRM_ELI_DATOS '||V_ERROR);
END;
/

