create or replace function it.fug_obt_fec_ext_ant (p_fecha date, p_nro_cuenta varchar2) Return date is
   V_FEC_ULT_EXTRACTO ge_ext_cli_cuentas.fec_extracto%type;
Begin
   BEGIN
     SELECT MAX(C.FEC_EXTRACTO) FEC_EXT_ANT
       INTO V_FEC_ULT_EXTRACTO
       FROM GE_EXT_CLI_CUENTAS C
      WHERE C.FEC_EXTRACTO <= TRUNC(LAST_DAY(ADD_MONTHS(p_fecha,-1)))
        AND C.NRO_CUENTA = p_NRO_CUENTA;
    EXCEPTION
      WHEN OTHERS THEN
        null;
    END;
  Return (v_fec_ult_extracto);
  
End;
/

