CREATE OR REPLACE FUNCTION IT.FUC_OBT_EXI_SOBREGIRO (P_NRO_CUENTA IN CC_LIN_SOBREGIROS.NRO_CUENTA%TYPE )
return varchar is
 v_existe varchar2(1);
begin
  select distinct'S'
    into v_existe
    from cc_lin_sobregiros
   where estado = 'A'
     and nro_cuenta = p_nro_cuenta;
  --
  return v_existe;
exception
  when others then
     return 'N';
end;
/

