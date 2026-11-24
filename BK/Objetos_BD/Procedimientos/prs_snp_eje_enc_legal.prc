create or replace procedure       it.prs_snp_eje_enc_legal(p_fecha IN ge_snp_mensajes.fec_valor%TYPE DEFAULT NULL) is

   v_ult_fecha   date;
   v_fec_proceso date := pag_cal.fu_obt_fec_actual(1) -1;
   v_dias        number;
   v_inicio      number;

begin
  
   
   IF p_fecha IS NULL THEN --> Funciona de forma normal antes del cambio
       --Se halla ultima fecha de envio
       select max(fec_valor)
         into v_ult_fecha
         from ge_snp_mensajes
        where cod_msj_swift = 998
          and fec_recepcion is null;
          
       v_inicio := 1; --Como no es reproceso comienza sumando 1 a la ultima fecha de proceso
       v_dias := v_fec_proceso - nvl(v_ult_fecha, v_fec_proceso);
       
   ELSE --TN-910 - Encaje Legal MT 998 - Reproceso
      v_ult_fecha := p_fecha;
      v_inicio := 0; --Como es reproceso comienza sumando 0 a la ultima fecha de proceso que se recibe por parametro
      v_dias :=  pag_cal.FU_OBT_FEC_SIG_HAB(p_fecha, 61, 1) - p_fecha -1; --resto 1 porque el siguiente dia habil no debe procesar
   END IF;
   
   if v_dias <= 0 then
      prs_snp_gen_enc_legal(v_ult_fecha);
   else
      for i in v_inicio .. v_dias loop
         prs_snp_gen_enc_legal(v_ult_fecha + i);
      end loop;
   end if;
   
   COMMIT;

end prs_snp_eje_enc_legal;
/