CREATE OR REPLACE TRIGGER IT."TB_GE_PAG_PROVEEDORES_TMP"
 BEFORE INSERT
 ON GE_PAG_PROVEEDORES_TMP
 FOR EACH ROW
DECLARE
  v_cant NUMBER default 0;
BEGIN

   if inserting then
        --Inicializar Número de Secuencia si es Nulo
        if pae_cnf.g_nro_secuencia is null then
          pae_cnf.g_nro_secuencia := -999;
        end if;
        begin
          --UES-1849
        :New.nro_secuencia := pae_cnf.fu_obt_sig_secuencia;
        exception
           WHEN OTHERS THEN
          IF SQLCODE = -6502 THEN
            pae_cnf.g_nro_secuencia := -999;
          ELSE
            raise_application_Error(-20000, 'ERROR AL OBTENER SECUENCIA ' || SQLERRM );
          end if;
          
        end;
        if :new.for_pago = 'I' and :new.nro_cta_credito is not null and :new.nro_cta_beneficiario is not null then
          :new.nro_cta_credito := null;
        end if;
        if :new.for_pago = 'I' and :new.fec_pago is null then
          --hallar horario
          begin
            select count(*)
              into v_cant
              from ge_snp_horarios b
             where b.estado = 'A'
               and exists (select 1
                             from ge_snp_par_mensajes a
                            where a.cod_msj_swift in (102, 103)
                              and b.cod_periodo in (a.cod_periodo,
                                                    a.cod_periodo2,
                                                    a.cod_periodo3));
          
          exception
            when no_data_found then
              null;
            when others then 
              null;
          end;
          if v_cant = 0 then
            :new.fec_pago := pag_cal.fu_obt_fec_proxima(1);
          else
            :new.fec_pago := pag_cal.fu_obt_fec_actual(1);
          end if;
        end if;
    end if;
END;
/
