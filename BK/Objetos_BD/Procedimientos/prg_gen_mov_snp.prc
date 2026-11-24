CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_SNP
(  p_hora           IN  VARCHAR2,
   p_fecha          IN  DATE     DEFAULT NULL,
   p_cod_usuario    IN  VARCHAR2 DEFAULT NULL,
   p_cod_programa   OUT VARCHAR2,
   p_nro_referencia OUT VARCHAR2 )
IS




   v_nro_referencia    ge_snp_transferencias.nro_referencia%type := NULL;
   v_fecha             ge_snp_transferencias.fecha%type;
   v_fec_valor         ge_snp_transferencias.fec_valor%type;
   v_cod_msj_swift     ge_snp_transferencias.cod_msj_swift%type;
   v_tip_operacion     ge_snp_transferencias.cod_tip_operacion%type;
   v_sub_tip_operacion ge_snp_transferencias.cod_sub_tip_operacion%type;
   v_ind_valor         ge_snp_transferencias.ind_valor%type := 'N';
   v_cod_swi_benef     ge_snp_transferencias.cod_swi_pte_beneficiario%type;
   v_nro_cta_benef     ge_snp_transferencias.nro_cta_beneficiario%type;
   v_prioridad         ge_snp_transferencias.prioridad%type := 20;
   v_nro_cta_sol       ge_cuentas.nro_cuenta%type;
   v_cod_modulo        ba_modulos.cod_modulo%type;
   v_cod_modalidad     ge_modalidades.cod_modalidad%type;
   v_cod_oficina       ba_oficinas.cod_oficina%type;
   v_concepto          ge_movimientos.concepto%type;
   v_con_movimiento    ge_movimientos.concepto%type;
   v_monto             ge_movimientos.monto%type;
   v_cod_moneda        ba_monedas.cod_moneda%type;
   v_cod_persona       ba_personas.cod_persona%type;
   

   CURSOR datos IS
      SELECT m.fec_valor,
             m.cod_tra_padre,
             m.cod_mad_padre,
             m.cod_transaccion,
             m.cod_modulo,
             m.cod_modalidad,
             m.monto,
             m.cod_moneda,
             m.nro_cuenta,
             m.cod_ofi_origen cod_oficina,--m.cod_oficina, --wa:28/11/2013 para que guarde la Ofic. del que hace la Operacion
             m.nro_documento,
             m.nro_documento2,
             m.concepto,
             m.cod_banco,
             m.referencia
        FROM ge_movimientos m
       WHERE m.fecha         = v_fecha
         AND m.hora          = p_hora
         AND m.cod_usuario   = p_cod_usuario
         --AND m.cod_tra_padre = 303
         AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
         AND m.cod_mad_padre = 455
         AND m.nro_documento2 IS NOT NULL
       ORDER by m.nro_secuencia DESC;
BEGIN
   IF p_fecha IS NULL THEN
      v_fecha := pas_snp.g_fec_actual;
   ELSE
      v_fecha := p_fecha;
   END IF;
   p_cod_programa  := NULL ;
   BEGIN
       FOR dt IN datos LOOP
           v_cod_msj_swift     := substr(dt.nro_documento2,1,3);
           v_tip_operacion     := substr(dt.nro_documento2,4,3);
           v_sub_tip_operacion := substr(dt.nro_documento2,7,3);
           IF v_cod_msj_swift IN ( 102, 103, 202 ) AND dt.cod_modalidad = 455 THEN
              --Solo si es un DEBITO a la CTA. INTERBANCARIA en la entidad, entonces es un MT102
              v_fec_valor     := dt.fec_valor;
              v_cod_modulo    := dt.cod_modulo;
              v_cod_modalidad := dt.cod_modalidad;
              v_cod_moneda    := dt.cod_moneda;
              v_monto         := dt.monto;
              v_cod_oficina   := dt.cod_oficina;
              v_concepto      := dt.concepto;
              v_cod_persona   := fug_obt_cli_principal(dt.nro_cuenta) ;
              IF v_cod_msj_swift = 202 THEN
                 p_cod_programa := 'gmsnp202';
                 v_ind_valor    := 'S';
              END IF ;
           ELSIF v_cod_msj_swift IN ( 102, 103 ) AND dt.cod_modalidad <> 455 THEN
              --Si es un DEBITO evaluar si se debita solamente al cliente
              v_nro_cta_sol       := dt.nro_cuenta;
              p_cod_programa      := 'gmsnp103';
              v_cod_persona       := fug_obt_cli_principal(dt.nro_cuenta) ;

              IF pae_cnf.g_programa = 'AMTRCSER' /*AND dt.cod_transaccion = 4030*/ THEN
                 -- Se agrega para DNA
                 v_nro_cta_benef     := dt.referencia;
                 /*BEGIN
                    SELECT gv.cod_swift
                      INTO v_cod_swi_benef
                      FROM gv_snp_participantes gv
                     WHERE gv.cod_banco = dt.cod_banco;
                 EXCEPTION
                    WHEN OTHERS THEN
                       v_cod_swi_benef := NULL;
                 END;*/
              END IF;

              IF v_cod_msj_swift = 102 THEN
                 v_ind_valor     := 'N';
              ELSE
                 v_ind_valor     := 'S';
              END IF;
           END IF;
       END LOOP;
   END ;
       --
   IF p_cod_programa IS NOT NULL THEN
      --Cargar datos mas importantes en la tabla ge_tra_interbancarias
      BEGIN
        SELECT nro_referencia
          INTO v_nro_referencia
          FROM ge_snp_transferencias t
         WHERE t.fecha        = v_fecha
           AND t.hora         = p_hora
           AND t.cod_usuario  = nvl( p_cod_usuario, USER );

      EXCEPTION
         WHEN no_data_found THEN
           BEGIN
              /* Inicializa variables */
              pas_snp.g_msj := NULL;
              --
              BEGIN
                 SELECT m.prioridad
                   INTO v_prioridad
                   FROM ge_snp_par_mensajes m
                  WHERE m.cod_msj_swift                  = v_cod_msj_swift
                    AND m.cod_tip_operacion              = v_tip_operacion
                    AND nvl(m.cod_sub_tip_operacion,'x') = nvl(v_sub_tip_operacion,'x')
                    AND nvl(m.cod_tra_padre, pas_snp.fu_obt_cod_tra_padre) = pas_snp.fu_obt_cod_tra_padre;
              EXCEPTION
                 WHEN others THEN
                   v_prioridad := CASE nvl( v_cod_msj_swift, 102 )
                                    WHEN 102 THEN 100
                                    ELSE 20
                                  END; -- Cualquier error coloca la prioridad por defecto
              END;

              v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;

              pas_snp.g_msj.nro_referencia          := v_nro_referencia;
              pas_snp.g_msj.cod_modulo              := v_cod_modulo;
              pas_snp.g_msj.cod_modalidad           := v_cod_modalidad;
              pas_snp.g_msj.cod_oficina             := v_cod_oficina;
              pas_snp.g_msj.fec_valor               := v_fec_valor;
              pas_snp.g_msj.fec_ingreso             := v_fecha;
              pas_snp.g_msj.fecha                   := v_fecha;
              pas_snp.g_msj.hora                    := p_hora;
              pas_snp.g_msj.cod_usuario             := nvl( p_cod_usuario, USER );
              pas_snp.g_msj.nro_operacion           := v_nro_referencia;
              pas_snp.g_msj.cod_moneda              := v_cod_moneda;
              pas_snp.g_msj.cod_tip_operacion       := v_tip_operacion;
              pas_snp.g_msj.cod_sub_tip_operacion   := v_sub_tip_operacion;
              pas_snp.g_msj.monto                   := v_monto;
              pas_snp.g_msj.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
              -- Si el Nro. Cta del Solicitante tiene algún valor entonces se recupera los datos de la persona relacionada a ella.
              IF v_nro_cta_sol IS NOT NULL THEN
                 pas_snp.g_msj.cod_per_solicitante     := fug_obt_cli_principal( v_nro_cta_sol );
                 pas_snp.g_msj.nom_solicitante         := fue_obt_nom_persona( fug_obt_cli_principal( v_nro_cta_sol ) );
                 pas_snp.g_msj.dir_solicitante         := fue_obt_dir_principa( fug_obt_cli_principal( v_nro_cta_sol ) );
                 pas_snp.g_msj.cod_tip_doc_solicitante := fue_obt_doc_principal( pas_snp.g_msj.cod_per_solicitante ) ;
                 pas_snp.g_msj.nro_doc_solicitante     := substr(fue_obt_nro_doc_persona( fug_obt_cli_principal( v_nro_cta_sol ) ),1,20);
                 pas_snp.g_msj.nro_cta_solicitante     := v_nro_cta_sol;
              END IF;
              --
              v_con_movimiento := 'Transf Local via BCP Ref ' || v_nro_referencia;
              --
              pas_snp.g_msj.concepto                 := nvl( v_concepto, v_con_movimiento );
              pas_snp.g_msj.cod_msj_swift            := v_cod_msj_swift;
              pas_snp.g_msj.ind_valor                := v_ind_valor;
              pas_snp.g_msj.prioridad                := v_prioridad;
              pas_snp.g_msj.situacion                := 'P';
              pas_snp.g_msj.estado                   := 'S';
              -- Para DNA
              IF v_nro_cta_benef IS NOT NULL THEN
                 pas_snp.g_msj.cod_swi_pte_beneficiario := v_cod_swi_benef ;
                 pas_snp.g_msj.nro_cta_beneficiario     := v_nro_cta_benef ;
              END IF;
              pas_snp.g_lugar :=  'Insertando Mensajería.., ';
              pas_snp.pr_ins_transferencias ( pas_snp.g_msj );

              --Una vez registrada la mensajería, se ACTUALIZA el movimiento con el NRO_REFERENCIA y NRO_SEC_LOTE
              BEGIN
                 UPDATE ge_movimientos m
                    SET m.nro_documento  = to_number( substr( v_nro_referencia,1,15 ) ),
                        m.concepto       = DECODE( m.nro_documento2, NULL, m.concepto, v_con_movimiento )
                  WHERE m.hora           = p_hora
                    AND m.cod_usuario    = nvl( p_cod_usuario, USER )
                    AND m.fecha          = v_fecha
                    --AND m.cod_tra_padre  = 303
                    AND m.cod_tra_padre in (Select distinct x.cod_tra_padre from ge_snp_par_mensajes x) -- SNP
                    AND m.monto          > 0;
                 IF sql%notfound THEN
                    raise_application_error(-20000, 'No se ha podido RELACIONAR el movimiento con el SWIFT generado. Fecha: '|| to_char( v_fecha,'DD/MM/YYYY' ) ||
                                                                                                                    ' Hora: '|| p_hora ||
                                                                                                                    ' Usu : '|| nvl( p_cod_usuario, USER ) );
                 END IF;
              END;
              --
              pas_snp.pr_ini_workflow( pas_snp.g_msj );
              if pas_snp.fu_obt_cod_error <> 0 then
                 raise_application_error (-20001, pas_snp.fu_obt_msj_error);
              else
                 commit ;-- Con esto se tiene la integridad del circuito de datos para su posterior seguimiento en el WF.
              end if;
              --
           END;
      END;
      -- Devuelve los datos del MT relacionado al movimiento
      p_nro_referencia := v_nro_referencia;
   END IF;
EXCEPTION
   WHEN dup_val_on_index THEN
      raise_application_error( -20001,' Ya existen registros en ge_snp_transferencias para el número de transferencia '||p_nro_referencia||', verifique.!' );
   WHEN others then
      IF sqlcode < -20000 THEN
         raise;
      ELSE
         raise_application_error( -20002,'Error en prg_gen_mov_snp' || '-' || sqlerrm );
      END IF;
END;
/

