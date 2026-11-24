CREATE OR REPLACE FUNCTION IT.fut_obt_des_tip_cierre
 (P_COD_TIP_CIERRE IN TA_TIP_CIERRES.COD_TIP_CIERRE%TYPE
 )
 RETURN VARCHAR2
 IS

V_DESCRIPCION TA_TIP_CIERRES.DESCRIPCION%TYPE;
Begin
   --Obtiene la descripción del tipo de cierre
   select descripcion
     into v_descripcion
     from ta_tip_cierres
    where cod_tip_cierre = p_cod_tip_cierre;

    return v_descripcion;

    exception
       when no_data_found then
           return('Tipo de cierre no registrado en el Sistema');
End;
/

