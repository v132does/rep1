create or replace function it.fus_obt_desencajes(
   p_fecha date,
   p_cod_moneda ba_monedas.cod_moneda%type)
return number is
   v_redondeo  NUMBER(10):= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, p_cod_moneda);
   v_cod_mon_bcp ba_monedas.cod_mon_bco_central%type;
   v_ult_fecha date;
   Result number;
begin
   --Se halla ultima fecha de proceso, por si sea sábado, domingo o feriado
   select max(fec_proceso)
     into v_ult_fecha
     from sb_desencajes a
    where a.fec_proceso <= p_fecha;
   --Se halla la moneda ISO.
   begin
      select m.cod_mon_bco_central
        into v_cod_mon_bcp
        from ba_monedas m
       where m.cod_moneda = p_cod_moneda;
   exception
       when others then
          v_cod_mon_bcp := null;
   end;
   ---
   if v_cod_mon_bcp is not null then
      select round(nvl(sum(nvl(importe,0)),0),v_redondeo)
        into Result
        from sb_enc_circular254
       where fecha = v_ult_fecha
         and plazo = '99'
         and cod_moneda = v_cod_mon_bcp;
   end if;
   ---
   return(Result);
   ---
end fus_obt_desencajes;
/

