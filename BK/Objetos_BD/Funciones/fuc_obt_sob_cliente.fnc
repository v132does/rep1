create or replace function it.fuc_obt_sob_cliente (p_cod_persona varchar2)
return number IS
v_mto_sobregiro number(20,3):=0;
v_mto_linea number(20,3):=0;
v_cod_persona ba_personas.cod_persona%type;
begin
  begin
  select abs(sum(pag_gen.fu_con_mon_a_moneda(cc_cta_corrientes.cod_moneda,'GS',cc_cta_corrientes.sal_total))
             ),
         ge_cta_clientes.cod_persona
  into v_mto_sobregiro, v_cod_persona
    from cc_cta_corrientes, ge_cta_clientes
     where cc_cta_corrientes.estado <> 'C'
     and cc_cta_corrientes.nro_cuenta = ge_cta_clientes.nro_cuenta
     and ge_cta_clientes.relacion = 'P'
     and sal_total < 0
     and ge_cta_clientes.cod_persona = p_cod_persona
     group by ge_cta_clientes.cod_persona ;
     exception
     when no_data_found then
     v_mto_sobregiro := 0;
     end;
    begin
    select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda,'GS',monto))
    into  v_mto_linea
      from cc_lin_sobregiros l
      where l.cod_persona = p_cod_persona
      and estado = 'A'
      and tipo = 'P';
      exception
      when no_Data_found then
      v_mto_linea := 0;
    end;
IF v_mto_sobregiro > v_mto_linea THEN
  return(v_mto_sobregiro - v_mto_linea);
ELSE
--return(0);
  If nvl(v_mto_linea,0) = 0 then
    return v_mto_sobregiro;
  else
    return(0);
  End if;
END IF;
end;
/

