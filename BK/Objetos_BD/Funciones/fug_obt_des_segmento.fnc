CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_SEGMENTO
 (p_cod_seg_cliente ge_seg_clientes.cod_seg_cliente%TYPE)
 RETURN varchar2
 IS
V_DESCRIPCION ge_seg_clientes.descripcion%TYPE;
Begin
    --Obtiene la descripción del segmento del cliente
    select descripcion
      into v_descripcion
      from ge_seg_clientes
     where cod_seg_cliente = p_cod_seg_cliente;
    return v_descripcion;
    exception
       when no_data_found then
           return('Segmento del Cliente No Especificado');
End;
/

