CREATE OR REPLACE PROCEDURE IT.PRG_OBT_DAT_CON_FIRMAS (p_cod_modulo       in number,
                                                    p_cod_modalidad    in number,
                                                    p_cod_transaccion  in number,
                                                    p_tip_control     out varchar2,
                                                    p_cod_facultad    out varchar2,
                                                    p_ser_fir_externo out varchar2,
                                                    p_nro_ord_importe out varchar2) IS
BEGIN
     If fug_obt_pardinamico('CAJ_CON_FIR_EXTERNO') = 'S' Then -- solo se verifica si esta activo
       Select tip_control  , cod_facultad  , nro_ord_importe
         into p_tip_control, p_cod_facultad, p_nro_ord_importe
         From ge_tra_firmas
        Where cod_modulo      = p_cod_modulo
          and cod_modalidad   = p_cod_modalidad
          and cod_transaccion = p_cod_transaccion;
        p_ser_fir_externo :=  fug_obt_pardinamico('CAJ_SER_FIR_EXTERNO');  
     Else
        p_tip_control     := 'N';
        p_cod_facultad    := '0';
        p_ser_fir_externo := fug_obt_pardinamico('CAJ_SER_FIR_EXTERNO');  
        p_nro_ord_importe := '0';
     End If;      
EXCEPTION
    WHEN NO_DATA_FOUND THEN
         p_tip_control     := 'N';
         p_cod_facultad    := '';
         p_ser_fir_externo := '';
         p_nro_ord_importe := '';
    WHEN TOO_MANY_ROWS THEN
         raise_application_error(-20001, 'Transacción duplicada en ge_tra_firmas. Verifique.');
END;
/

