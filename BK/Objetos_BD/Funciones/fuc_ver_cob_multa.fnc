create or replace function it.FUC_VER_COB_MULTA
(P_NRO_CUENTA   cc_che_devueltos.nro_cuenta%TYPE,
 P_NRO_CHEQUE   cc_che_devueltos.nro_cheque%TYPE)
  return varchar2 is
--verifica si ya se cobró multa por este cheque
--devuelve 'S' si ya se cobró alguna vez,
--         'N' si nunca se le cobró.
  v_cob_multa varchar2(1);
begin

  Select 'S' into v_cob_multa
    from cc_che_devueltos
   where nro_cuenta = p_nro_cuenta
     and nro_cheque = p_nro_cheque
     and multa > 0;
  return(v_cob_multa);
exception
  when no_data_found then
    return 'N';
  when too_many_rows then
    return 'S';
  when others then
    return 'S';
end FUC_VER_COB_MULTA;
/

