create or replace procedure it.prs_snp_eje_pre_legal is
   v_ult_fecha   date;
   v_fec_proceso date := pag_cal.fu_obt_fec_actual(1) -1;
   v_dias        number;
begin
   --Se halla ultima fecha de envio
   select max(fec_valor)
     into v_ult_fecha
     from ge_snp_mensajes
    where cod_msj_swift = 998
      and fec_recepcion is null;
   v_dias := v_fec_proceso - nvl(v_ult_fecha, v_fec_proceso);
   if v_dias <= 0 then
      pag_evo.pr_snp_pre_enc_legal(v_fec_proceso);
   else
      for i in 1..v_dias loop
         pag_evo.pr_snp_pre_enc_legal(v_ult_fecha + i);
      end loop;
   end if;
end prs_snp_eje_pre_legal;
/

