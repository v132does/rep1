CREATE OR REPLACE TRIGGER IT.TB_GE_SNP_TRANSFERENCIAS
 BEFORE UPDATE OF SITUACION, ESTADO
 ON it.GE_SNP_TRANSFERENCIAS
 FOR EACH ROW
DECLARE
  rg_msj pas_snp.rg_msj; --Tipo registro (GE_SNP_TRANSFERENCIAS) definido en PAS_SNP.
  v_cant      number;
  v_cod_error                   number(10);
  v_men_error                    varchar2(2000);
  v_inf_json                 long:=null;
  v_aviso                    varchar2(2000);
  procedure pr_ins_cli_ocacional(p_nro_documento varchar2, p_nombre varchar2) is
    v_tip_doc ba_tip_documentos.cod_tip_documento%type;
    v_pri_nombre ba_per_fisicas.pri_nombre%type;
    v_pri_apellido ba_per_fisicas.pri_apellido%type;
    v_nro_documento ba_cli_ocasionales.nro_documento%type;

  begin
    if p_nro_documento is not null then
      if p_nro_documento like '%-%' then
        v_tip_doc := 6;
      else
        v_tip_doc := 1;
      end if;
      if p_nro_documento like '0%' then
        begin
          v_nro_documento := to_number(p_nro_documento);
        exception
          when others then
            v_nro_documento := p_nro_documento;
        end;
      else
        v_nro_documento := p_nro_documento;
      end if;
      v_pri_nombre := trim(substr(fug_obt_nombre(upper(p_nombre),1),1,30));
      v_pri_apellido := trim(substr(fug_obt_nombre(upper(p_nombre),2),1,30));
      v_nro_documento := replace(replace(v_nro_documento,'.'),',');
      begin
        insert into ba_cli_ocasionales(cod_tip_documento, nro_documento, pri_nombre, pri_apellido,
                                       cod_pai_nacionalidad, fec_nacimiento, cod_oficina)
        values(v_tip_doc, v_nro_documento, v_pri_nombre, v_pri_apellido, 1, to_date('01/01/1965','dd/mm/yyyy'), :new.cod_oficina );
      exception
        when dup_val_on_index then null;
        when others then null;
      end;
    end if;
  end;
BEGIN
   if updating then
      if :new.situacion <> :old.situacion and
         :new.fecha is null               and --
         :new.hora is null                and -- No debe tener movimientos relacionados a la Mensajería
         :new.cod_usuario is null             --
      then
         /**/-- Para MTs RECIBIDOS                        ( Generar Movimiento cuando el estado es SOLICITADO y la nueva situación es LIQUIDADA. )
         /**/-- Para MTs ENVIADOS - [Operaciones Futuras] ( Generar Movimiento cuando el estado es APROBADO y la nueva situación es LIQUIDADA. )
         /**/--                                           ( Generar Movimiento cuando el estado es ENVIADO A BCP y la nueva situación es LIQUIDADA. )
         if ( :old.estado = 'S' and :new.situacion = 'L' ) or -- MTs RECIBIDOS
            ( :old.estado = 'A' and :new.situacion in ('L', 'V' ) ) -- MTs ENVIADOS - Operaciones Futuras
         then

             pas_snp.pr_ini_registros;

             rg_msj.nro_referencia           := :new.nro_referencia;
             rg_msj.nro_sec_lote             := :new.nro_sec_lote;
             rg_msj.cod_modulo               := :new.cod_modulo;
             rg_msj.cod_modalidad            := :new.cod_modalidad;
             rg_msj.cod_oficina              := :new.cod_oficina;
             rg_msj.cod_tip_operacion        := :new.cod_tip_operacion;
             rg_msj.cod_sub_tip_operacion    := :new.cod_sub_tip_operacion;
             rg_msj.cod_msj_swift            := :new.cod_msj_swift;
             rg_msj.fec_recepcion            := :new.fec_recepcion;
             rg_msj.fec_ingreso              := :new.fec_ingreso;
             rg_msj.fec_valor                := :new.fec_valor;
             rg_msj.fecha                    := :new.fecha;
             rg_msj.hora                     := :new.hora;
             rg_msj.cod_usuario              := :new.cod_usuario;
             rg_msj.cod_moneda               := :new.cod_moneda;
             rg_msj.monto                    := :new.monto;
             rg_msj.cod_per_solicitante      := :new.cod_per_solicitante;
             rg_msj.nom_solicitante          := :new.nom_solicitante;
             rg_msj.dir_solicitante          := :new.dir_solicitante;
             rg_msj.nro_doc_solicitante      := :new.nro_doc_solicitante;
             rg_msj.nro_cta_solicitante      := :new.nro_cta_solicitante;
             rg_msj.cod_swi_pte_solicitante  := :new.cod_swi_pte_solicitante;
             rg_msj.nro_cta_pte_solicitante  := :new.nro_cta_pte_solicitante;
             rg_msj.cod_per_beneficiario     := :new.cod_per_beneficiario;
             rg_msj.nom_beneficiario         := :new.nom_beneficiario;
             rg_msj.dir_beneficiario         := :new.dir_beneficiario;
             rg_msj.nro_doc_beneficiario     := :new.nro_doc_beneficiario;
             rg_msj.nro_cta_beneficiario     := :new.nro_cta_beneficiario;
             rg_msj.cod_swi_pte_beneficiario := :new.cod_swi_pte_beneficiario;
             rg_msj.nro_cta_pte_beneficiario := :new.nro_cta_pte_beneficiario;
             rg_msj.concepto                 := :new.concepto;
             rg_msj.observacion              := :new.observacion;
             rg_msj.tip_cargo                := :new.tip_cargo;
             rg_msj.ind_valor                := :new.ind_valor;
             rg_msj.nro_ref_externa          := :new.nro_ref_externa;
             rg_msj.situacion                := :new.situacion;
             rg_msj.estado                   := :new.estado;
             rg_msj.prioridad                := :new.prioridad;
             rg_msj.nro_operacion            := :new.nro_operacion;
             rg_msj.tip_mensaje              := :new.tip_mensaje;
             rg_msj.error                    := :new.error;
             rg_msj.origen                   := :new.origen;
             rg_msj.plataforma               := :new.plataforma;
             rg_msj.indemnizado              := :new.indemnizado;
             rg_msj.cod_servicio             := :new.cod_servicio;
             rg_msj.ref_oid                  := :new.ref_oid;
             rg_msj.cod_swi_suc_beneficiario := :new.cod_swi_suc_beneficiario;
             rg_msj.cod_swi_suc_solicitante  := :new.cod_swi_suc_solicitante;
             rg_msj.cod_tip_doc_solicitante  := :new.cod_tip_doc_solicitante; 
             rg_msj.cod_tip_doc_beneficiario := :new.cod_tip_doc_beneficiario;
             --Genera el movimiento a partir del SWIFT.
             pas_snp.pr_pro_principal ( rg_msj );
             --
             :new.situacion     := rg_msj.situacion;
             :new.estado        := rg_msj.estado;
             :new.indemnizado   := rg_msj.indemnizado;
             --
             if rg_msj.error is not null then --Debe registrar el error, para visualizarlo en el WORKFLOW
                :new.error := rg_msj.error;
                -- Si tiene errores el PAS_SNP.PR_PRO_PRINCIPAL inicia WF durante la sesión actual.
                pas_snp.pr_ini_workflow ( rg_msj );
             else /* Si generó el movimiento actualiza el estado de la mensajería a APROBADO,
                  || y relaciona el movimiento a la mensajería.
                  */
                :new.fecha         := rg_msj.fecha;
                :new.hora          := rg_msj.hora;
                :new.cod_usuario   := rg_msj.cod_usuario;
                :new.nro_operacion := rg_msj.nro_operacion;
                /*
                DA-7828 - Verifica si la transferencia a liquidar cumple las condiciones para enviar notificación
                */
                if :new.cod_msj_swift in(102,103,8,4) then
                    it.prg_gen_aler_tra_rrhh(rg_msj,'S');
                end if;
             end if;
             -- Validación de nombre y apellido para SPI - Clientes Ocasionales
             if :new.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
                pr_ins_cli_ocacional(:new.nro_doc_solicitante,  substr(:new.nom_solicitante, 1, 50));
                pr_ins_cli_ocacional(:new.nro_doc_beneficiario, substr(:new.nom_beneficiario, 1, 50));
             else
                pr_ins_cli_ocacional(:new.nro_doc_solicitante, :new.nom_solicitante);
                pr_ins_cli_ocacional(:new.nro_doc_beneficiario, :new.nom_beneficiario);
             end if;
             --
         end if;
      end if;
     if  :new.situacion='P' and :new.fec_recepcion is null and :new.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
       begin
         select count(*)
           into v_cant
           from ge_spi_log_controles t
          where t.nro_referencia = :new.nro_referencia
            and t.nro_ref_externa = :new.nro_ref_externa;
       exception
         when no_data_found then
           v_cant := 0;
         when others then
           v_cant := 0;
       end;
      if v_cant >= fug_obt_pardinamico( 'SPI_CANT_REINTENTO' ) then
          :new.situacion     := 'C';
          :new.estado        := 'R';
         /*
         || Emisor con Inconvenientes por Intermitencia (reintentos fallidos)
         || caso5
         */
         --Envio de sms
         begin
           prg_env_sms_spi(:new.cod_per_solicitante,
                           455,
                           'GEN_ENV_SMS_TRA_SPI_RF',
                           v_cod_error,
                           v_men_error);
         exception
           when others then
             null; --no realiza accion si da error envio de sms
         end;
         --Envio de mail
         begin
           v_aviso    := fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_RF');
           v_inf_json := '{' || '"fec_transferencia":' || '"' ||
                         to_char(:new.fec_insercion,
                                 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' ||
                         '"nom_beneficiario":' || '"' ||
                         :new.nom_beneficiario || '"' || ',' || '"monto":' || '"' ||
                         ltrim(rtrim(to_char(:new.monto,
                                             '999,999,999,999,999.99'))) || ' ' ||
                         initcap(:new.cod_moneda) || '.' || '"' || ',' ||
                         '"aviso":' || '"' || v_aviso || '"' || '}';
           --Insertar correo para el solicitante
           pas_spi.pr_env_alerta(:new.cod_per_solicitante,
                                 fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',
                                                            'ENVNOTRF'),
                                 v_inf_json);
         exception
           when others then
             null; --no realiza accion si da error envio de correo
         end;
       end if;
    end if;
   end if;
EXCEPTION
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'Error en TB_GE_SNP_TRANSFERENCIAS: '|| sqlerrm);
     end if;
END;
/

