create or replace procedure it.PRG_PRO_MSJ_SNP_INV is
Begin
DECLARE
 v_referencia varchar2(20);
 v_err_code       NUMBER(5);
 v_err_msj        VARCHAR2(4000);
 v_hor_proceso    date;
 v_lote           ge_snp_transferencias.nro_lote%type;
 
 cursor datos is
 select t.nro_referencia,t.fec_insercion
 from ge_snp_transferencias t, ge_snp_mensajes m
 where trunc(t.fec_insercion)  = trunc(sysdate)
  and t.estado = 'S'
  and t.situacion = 'R'
  and trunc(m.fec_insercion)  = trunc(sysdate)
  and to_char(t.nro_ref_externa) = to_char(m.nro_ref_externa)
  --No debe procesar las transferencias que ya están en el Worflow.
  and not exists (select 1    
                    from wf_circuitos c
                   where c.referencia = t.nro_referencia
                     and trunc(c.fec_insercion) = trunc(sysdate));
   
 cursor lotes is
 select t.nro_referencia, t.nro_lote
 from ge_snp_transferencias t, ge_snp_mensajes m
 where trunc(t.fec_valor) = trunc(sysdate)
   and trunc(m.fec_insercion) = trunc(sysdate)
   and t.nro_lote = m.nro_ref_externa
   and t.cod_msj_swift = 102 
   and m.cod_msj_swift = 196 -- mt de pre y confirmacion de lotes
   and t.estado='A'      -- aprobado
   and t.situacion ='V'  -- enviado al BCP
   and instr(m.msj_swift,'NETR') > 0  -- pre-confirmado
 order by 1; 
 
                   
BEGIN
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
   v_hor_proceso := (sysdate - 60 / 86400 );  --Hora de Ejecución del proceso menos 1 minuto
   for c in datos loop
      IF c.fec_insercion <= v_hor_proceso then -- Para que tome los mensajes recibidos 1 minuto atras, por si todavía no llego su MT910
          
          v_referencia := c.nro_referencia;
          --Recupera la mensajería
          pas_snp.pr_obt_mensaje( v_referencia, 'N' );
          if pas_snp.fu_obt_cod_error <> 0 then
             v_err_code := pas_snp.fu_obt_cod_error;
             v_err_msj  := substr(pas_snp.fu_obt_msj_error, 1, 4000);
             --No debe enviar e-mail, cuando el error ya está tratado por el PAS_SNP y genera Worflow
            /* INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error)
             VALUES (818, 'PRG_PRO_MSJ_SNP_INV', sysdate, sysdate, v_err_code, v_err_msj);
             COMMIT; */ 
             CONTINUE;
          end if; 
          -- Ejecuta el PAS_SNP.PR_PRO_PRINCIPAL para intentar generar movimientos 
          pas_snp.pr_pro_principal ( pas_snp.g_msj );
          if pas_snp.fu_obt_cod_error = 0 then 
             pas_snp.g_msj.situacion := 'L';
             pas_snp.g_msj.estado    := 'A';
             -- Actualiza la mensajería en GE_SNP_TRANSFERENCIAS
             pas_snp.pr_set_transferencias( pas_snp.g_msj );
             if pas_snp.fu_obt_cod_error <> 0 then 
                v_err_code := pas_snp.fu_obt_cod_error;
                v_err_msj  := substr(pas_snp.fu_obt_msj_error, 1, 4000);
                --No debe enviar e-mail, cuando el error ya está tratado por el PAS_SNP y genera Worflow
                /*INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error)
                VALUES (818, 'PRG_PRO_MSJ_SNP_INV', sysdate, sysdate, v_err_code, v_err_msj);
                COMMIT; */
                CONTINUE;
             end if; 
          else
             v_err_code := pas_snp.fu_obt_cod_error;
             v_err_msj  := substr(pas_snp.fu_obt_msj_error, 1, 4000);
             --No debe enviar e-mail, cuando el error ya está tratado por el PAS_SNP y genera Worflow
             /*INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error)
             VALUES (818, 'PRG_PRO_MSJ_SNP_INV', sysdate, sysdate, v_err_code, v_err_msj);
             COMMIT; */
             CONTINUE;
          end if; 
      End If;    
	  COMMIT;
   end loop;
   
  -- actualizamos los lotes que no se actualizaron con el pas_snp.fu_pro_msj_mtn96 al recibir la pre-confirmacion
  -- MTOP. Oct/2020
  for x in lotes loop
    v_lote := x.nro_lote;
    begin
      update ge_snp_transferencias
        set situacion ='O'
      where nro_referencia = x.nro_referencia
       and nro_lote = x.nro_lote
       and situacion ='V' 
       and estado ='A';
      
    exception
      when others then
        v_err_code := SQLCODE;
        v_err_msj  := substr(sqlerrm, 1, 4000);
        INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error, comentario)
        VALUES (818, 'PRG_PRO_MSJ_SNP_INV', sysdate, sysdate, v_err_code, v_err_msj, 'Actualizando lote '|| v_lote);
        COMMIT;     
    end;  
    commit;
  end loop;  
   
  EXCEPTION
    WHEN OTHERS THEN
      v_err_code := SQLCODE;
      v_err_msj  := substr(sqlerrm, 1, 4000);
      INSERT INTO ge_pro_aut_logs (cod_proceso,nom_proceso,fec_hor_ini,fec_hor_fin,nro_error,men_error)
      VALUES (818, 'PRG_PRO_MSJ_SNP_INV', sysdate, sysdate, v_err_code, v_err_msj);
      COMMIT;     
END;   
end PRG_PRO_MSJ_SNP_INV;
/

