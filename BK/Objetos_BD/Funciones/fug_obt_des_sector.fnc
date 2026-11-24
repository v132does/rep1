CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_SECTOR
 (p_cod_sec_credito pr_sec_creditos.cod_sec_credito%TYPE)
 RETURN varchar2
 IS
V_DESCRIPCION pr_sec_creditos.descripcion%TYPE;
Begin
    --Obtiene la descripción de destinado al sector
    select descripcion
      into v_descripcion
      from pr_sec_creditos
     where cod_sec_credito = p_cod_sec_credito;
    return v_descripcion;
    exception
       when no_data_found then
           return('Destino del Sector No Especificado');
End;
/

