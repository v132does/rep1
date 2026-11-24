CREATE OR REPLACE TRIGGER IT.TA_GE_SNP_CTA_ENTES
 BEFORE INSERT OR UPDATE
 ON GE_SNP_CTA_ENTES
 FOR EACH ROW
DECLARE
   v_cod_swift ge_bancos.cod_swift%type := NULL;
BEGIN
   if :new.ind_activo = 'S' then
      -- Actualizo los datos de la tabla ge_snp_transferencias con estado pendiente.            
      select gs.cod_swift
        into v_cod_swift
        from gv_snp_participantes gs
       where gs.cod_ente = :new.cod_ente;
      
      begin
        update ge_snp_transferencias gst
           set gst.nro_cta_pte_beneficiario = :new.nro_cta_bancaria
         where gst.cod_swi_pte_beneficiario = v_cod_swift
           and gst.cod_moneda = :new.cod_moneda
           and gst.nro_ref_externa is null
           and gst.situacion = 'P';
      exception
         when no_data_found then
            null;
         when others then
            raise_application_error(-20000,'Error al actualizar en la tabla ge_snp_transferencias') ;
      end;
   end if ;
EXCEPTION
   when others then
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error( -20002,'Error al verificar en GE_SNP_ENTES - ' || sqlerrm );
      END IF;
END;
/

