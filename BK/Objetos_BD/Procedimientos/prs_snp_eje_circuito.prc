CREATE OR REPLACE PROCEDURE IT.PRS_SNP_EJE_CIRCUITO( p_cod_circuito    IN wf_circuitos.cod_circuito%TYPE,
                                                  p_cod_tip_tarea   IN wf_cir_tareas.cod_tip_tarea%TYPE,
                                                  p_tip_accion      IN VARCHAR2,
                                                  p_comentario      IN VARCHAR2 DEFAULT NULL,
                                                  p_cod_cau_rechazo IN ge_causales.cod_causa%TYPE DEFAULT NULL
                                                ) IS
  v_referencia       ge_snp_transferencias.nro_referencia%type;
  v_cod_tip_circuito wf_circuitos.cod_tip_circuito%type;
  rg_msj             pas_snp.rg_msj;
  v_asunto           varchar2(50);
  v_texto            varchar2(50);
  v_dir_correo       varchar2(100);
  v_fec_actual       constant date    := pag_cal.fu_obt_fec_actual(1);                           

  --Procedimiento interno para el tipo de acción Aprobar.
  PROCEDURE lp_tip_acc_aprobar( p_cod_tip_circuito in     wf_circuitos.cod_tip_circuito%type,
                                p_cod_tip_tarea    in     wf_cir_tareas.cod_tip_tarea%type,
                                rg_msj             in out pas_snp.rg_msj
                              ) is
   BEGIN
     IF p_cod_tip_tarea = 0 THEN
        --Se actualiza nuevamente la mensajería para que cambie el valor del USU_MODIFICACION
        pas_snp.pr_set_transferencias( rg_msj );
        IF pas_snp.fu_obt_cod_error <> 0 THEN
           raise_application_error( -20100, pas_snp.fu_obt_msj_error );
        END IF;
     ELSIF (p_cod_tip_tarea <>0 OR fug_obt_pardinamico('SIB_SNP_EJE_CIRCUITO') = 'S' )THEN
        IF rg_msj.usu_modificacion = USER THEN
           raise_application_error( -20101, 'No se puede APROBAR una transferencia modificada por el mismo Usuario.' );
        END IF;
        IF pas_snp.fu_val_es_enviado( rg_msj ) AND
           rg_msj.cod_msj_swift <> 202 AND
           (   rg_msj.nro_cta_pte_beneficiario IS NULL
            OR rg_msj.nro_cta_beneficiario IS NULL
            OR rg_msj.nom_beneficiario IS NULL
           )
        THEN
           raise_application_error( -20102, 'Datos obligatorios del beneficiario no fueron cargados correctamente.' );
        END IF;
        IF rg_msj.error IS NOT NULL THEN
           raise_application_error( -20103, 'La mensajería actual contiene ERRORES, no se puede continuar.' );
        END IF;
        IF rg_msj.cod_msj_swift!=fug_obt_pardinamico ('COD_SPI_PCD') AND
           rg_msj.cod_msj_swift != fug_obt_pardinamico('COD_SPI_DEV') THEN
            IF rg_msj.msj_swift IS NULL AND
               ( ( pas_snp.fu_val_es_enviado( rg_msj ) AND rg_msj.ind_valor = 'S' )
                OR NOT pas_snp.fu_val_es_enviado( rg_msj )
               )
            THEN
               raise_application_error( -20104, 'MENSAJE SWIFT no generado, verifique la Operación.'||p_cod_circuito );
            END IF;
        END IF;
        IF pas_snp.fu_val_es_enviado( rg_msj ) THEN
          IF rg_msj.cod_msj_swift=fug_obt_pardinamico ('COD_SPI_PCD') or rg_msj.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_DEV') THEN --pacs.008: Mensaje de pago de Crédito Directo
             IF pas_snp.fu_obt_est_horario( rg_msj.cod_msj_swift,
                                             rg_msj.cod_tip_operacion,
                                             rg_msj.cod_sub_tip_operacion
                                           ) <> 'A'
              THEN
                 raise_application_error( -20105, pas_snp.fu_obt_msj_error );
              ELSIF rg_msj.situacion = 'L' AND rg_msj.estado = 'A' THEN
                 paw_cir.g_msj_alerta := 'La transferencia actual ya fue liquidada.';
              ELSE
                if rg_msj.fec_valor  <=v_fec_actual then
                 rg_msj.estado := 'U';
                else
                   rg_msj.estado := 'A';
                end if;
                 pas_snp.pr_set_transferencias( rg_msj );
                 IF pas_snp.fu_obt_cod_error <> 0 THEN
                    raise_application_error( -20107, pas_snp.fu_obt_msj_error );
                  END IF;
              END IF;
          ELSE
           IF rg_msj.ind_valor = 'S' AND
              ( rg_msj.fec_valor = rg_msj.fec_ingreso OR
                p_cod_tip_circuito = 203
              )
           THEN
              IF pas_snp.fu_obt_est_horario( rg_msj.cod_msj_swift,
                                             rg_msj.cod_tip_operacion,
                                             rg_msj.cod_sub_tip_operacion
                                           ) <> 'A'
              THEN
                 raise_application_error( -20105, pas_snp.fu_obt_msj_error );
              ELSIF rg_msj.situacion = 'L' AND rg_msj.estado = 'A' THEN
                 paw_cir.g_msj_alerta := 'La transferencia actual ya fue liquidada.';
              ELSE
                 pas_snp.pr_gen_arc_swift( rg_msj.nro_referencia, 'N' );
                 IF pas_snp.fu_obt_cod_error <> 0 THEN
                    raise_application_error( -20106, pas_snp.fu_obt_msj_error );
                 END IF;
              END IF;
           ELSE
              rg_msj.estado := 'A';
              pas_snp.pr_set_transferencias( rg_msj );
              IF pas_snp.fu_obt_cod_error <> 0 THEN
                 raise_application_error( -20107, pas_snp.fu_obt_msj_error );
              END IF;
           END IF;
           END IF;
        ELSE -- Recibidos
           IF rg_msj.cod_msj_swift  IN ( 102, 103 ) AND
              rg_msj.cod_moneda <> fug_obt_mon_cta( rg_msj.nro_cta_beneficiario ) AND
              pas_snp.fu_obt_cod_error = 0
           THEN
              /*
              || Si la operación de la transferencia recibida implica cambio de monedas,
              || se verifica si existe contrato de cambios, proporcionando el número de documento
              || de la cuenta interbancaria del beneficiario
              */
              DECLARE
                 v_nro_con_cambio    lc_ope_pendientes.nro_operacion%type := NULL;
                 v_cta_debito        lc_ope_pendientes.cta_referencia%type;
                 v_cta_credito       lc_ope_pendientes.cta_referencia%type;
                 v_cotizacion        lc_ope_pendientes.cotizacion%type := NULL;
                 v_mto_debito        lc_ope_pendientes.monto%type := NULL;
                 v_mto_credito       lc_ope_pendientes.monto%type := NULL;
              BEGIN
                 v_cta_debito  := pas_snp.fu_obt_cta_bancaria( rg_msj.nro_cta_pte_beneficiario, 'C' );
                 v_cta_credito := rg_msj.nro_cta_beneficiario;
                 --
                 pas_snp.pr_ini_variables;
                 --
                 pas_snp.pr_obt_con_cambio( v_nro_con_cambio,
                                            'N',
                                            v_cta_debito,
                                            v_cta_credito,
                                            rg_msj.monto,
                                            rg_msj.cod_moneda,
                                            fug_obt_mon_cta( rg_msj.nro_cta_beneficiario ),
                                            v_cotizacion,
                                            v_mto_debito,
                                            v_mto_credito
                                          );
                 IF pas_snp.fu_obt_cod_error <> 0 THEN
                    raise_application_error( -20108, pas_snp.fu_obt_msj_error );
                 END IF;
              EXCEPTION
                 WHEN others THEN
                   IF sqlcode <= -20000 THEN
                      raise;
                   ELSE
                      raise_application_error( -20109, 'Buscando Contrato de Cambio: '||sqlerrm );
                   END IF;
              END;
           END IF;
           IF pas_snp.fu_obt_cod_error = 0 THEN
              rg_msj.situacion := 'L';
              rg_msj.estado    := 'A';
              pas_snp.pr_set_transferencias( rg_msj );
              IF pas_snp.fu_obt_cod_error <> 0 THEN
                 raise_application_error( -20110, pas_snp.fu_obt_msj_error );
              END IF;
           END IF;
           -- Se vuelve a consultar datos de la transferencia para verificar si se generó efectivamente el movimiento y la misma no contiene errores al APROBAR.
           DECLARE
              rg_msj_transferencia pas_snp.rg_msj;
           BEGIN
              pas_snp.pr_obt_mensaje(rg_msj.nro_referencia,'N');
              if pas_snp.fu_obt_cod_error <> 0 then
                 raise_application_error(-20111, 'No se ha encontrado datos de la mensajería para registrar en el LOG.');
              else
                 rg_msj_transferencia := pas_snp.fu_obt_reg_transferencias;
                 pas_snp.pr_ini_registros;
                 pas_snp.pr_reg_operacion( null,
                                           'Nro. Ref. Interna            : ' || '~' || to_char(rg_msj_transferencia.nro_referencia) || '~' || pas_snp.fu_obt_salto ||
                                           'Situación después de Liquidar: ' || '~' || rg_msj_transferencia.situacion || '~' || pas_snp.fu_obt_salto ||
                                           'Estado después de Liquidar   : ' || '~' || rg_msj_transferencia.estado || '~' || pas_snp.fu_obt_salto ||
                                           'Fecha Movimiento             : ' || '~' || to_char(rg_msj_transferencia.fecha,'DD/MM/YYYY') || '~' || pas_snp.fu_obt_salto ||
                                           'Hora Movimiento              : ' || '~' || rg_msj_transferencia.hora || '~' || pas_snp.fu_obt_salto ||
                                           'Usuario Movimiento           : ' || '~' || rg_msj_transferencia.cod_usuario || '~' || pas_snp.fu_obt_salto ||
                                           'Cod. Circuito                : ' || '~' || p_cod_circuito || '~' || pas_snp.fu_obt_salto
                                         );
              end if;
              if rg_msj_transferencia.situacion = 'L' and
                 rg_msj_transferencia.estado = 'A' and
                 rg_msj_transferencia.fecha is null and
                 rg_msj_transferencia.hora is null and
                 rg_msj_transferencia.cod_usuario is null
              then
                 raise_application_error( -20112, 'Error inesperado al intentar generar movimientos para el Nro. Referencia ' ||
                                                  rg_msj_transferencia.nro_referencia ||
                                                  '. Favor vuelva a intentar APROBAR la tarea.'
                                        );
              elsif rg_msj_transferencia.error is not null then
                 raise_application_error( -20113, 'Se han encontrado ERRORES para el Nro. Referencia ' ||
                                                  rg_msj_transferencia.nro_referencia ||
                                                  '. Favor verifíquelo y vuelva a intentar APROBAR la tarea.'
                                        );
              end if;
           EXCEPTION
             WHEN others THEN
               raise;
           END;
           IF pas_snp.fu_obt_cod_error <> 0 THEN
              raise_application_error( -20114, pas_snp.fu_obt_msj_error );
           END IF;
        END IF;
     END IF;
   EXCEPTION
     WHEN others THEN
       raise;
   END lp_tip_acc_aprobar;

  --Procedimiento interno para el tipo de acción Cancelar.
  PROCEDURE lp_tip_acc_cancelar( p_cod_tip_circuito    in     wf_circuitos.cod_tip_circuito%type,
                                 p_cod_tip_tarea       in     wf_cir_tareas.cod_tip_tarea%type,
                                 p_cod_cau_cancelacion in     ge_causales.cod_causa%type,
                                 rg_msj                in out pas_snp.rg_msj
                               ) is
   BEGIN
     IF (p_cod_tip_tarea <> 0 OR (fug_obt_pardinamico('SIB_SNP_EJE_CIRCUITO')='S' AND p_cod_tip_tarea <> 0)) THEN
        IF rg_msj.usu_modificacion = USER THEN
           raise_application_error(-20200, 'No se puede CANCELAR una transferencia modificada por el mismo Usuario.');
        END IF;
        IF pas_snp.fu_val_es_enviado( rg_msj ) THEN
           IF rg_msj.fecha IS NOT NULL AND
              rg_msj.hora IS NOT NULL AND
              rg_msj.cod_usuario IS NOT NULL
           THEN
              pas_snp.pr_rev_ope_con_swift (rg_msj.nro_referencia, 'Circuito de Aprobación CANCELADO');
              IF pas_snp.fu_obt_cod_error <> 0 THEN
                 raise_application_error( -20201, pas_snp.fu_obt_msj_error );
              END IF;
           ELSE
              rg_msj.estado := 'C';
              pas_snp.pr_set_transferencias (rg_msj);
              IF pas_snp.fu_obt_cod_error <> 0 THEN
                 raise_application_error( -20202, pas_snp.fu_obt_msj_error );
              END IF;
           END IF;
           v_asunto := 'Transacción Cancelada - SNP.';
           v_texto  := 'Se ha cancelado la operación. ';
           IF rg_msj.cod_usuario IS NULL AND
              rg_msj.usu_insercion IS NULL
           THEN
              raise_application_error( -20203, 'Error al recuperar el Usuario responsable del MT.' );
           END IF;
           v_dir_correo := fug_obt_dir_mail_usu( nvl( rg_msj.cod_usuario, rg_msj.usu_insercion ) );
           --cancelacion envio pacs.004--
             if rg_msj.cod_msj_swift = fug_obt_pardinamico( 'COD_SPI_DEV') then
                IF pas_snp.fu_obt_cod_error <> 0 THEN
                   raise_application_error( -20201, pas_snp.fu_obt_msj_error );
                else
                  rg_msj.situacion := 'C';
                  rg_msj.estado    := 'R';
                  pas_snp.pr_set_transferencias( rg_msj );
                  update ge_spi_solicitudes s
                     set s.sit_solicitud = 'C',
                         s.est_solicitud = 'R',
                         s.respuesta     = 'Circuito de Aprobación Cancelada'
                   where s.nro_referencia = rg_msj.nro_referencia
                     and s.fec_recepcion is null;
                END IF;
             end if;
             --spi fase 2
             if rg_msj.cod_msj_swift=fug_obt_pardinamico ('COD_SPI_PCD') then
                update ge_spi_solicitudes s
                set s.sit_solicitud = 'C',
                s.est_solicitud = 'R',
                s.respuesta     = 'Circuito de Aprobación Cancelada'
                where s.nro_referencia = rg_msj.nro_referencia
                and s.fec_recepcion is not null;
             end if;
        ELSE -- Es un MT Recibido
          IF nvl( p_cod_cau_cancelacion, -99 ) <> nvl( fug_obt_pardinamico( 'SNP_CAU_RECHAZO' ), 0 ) THEN
             --Intenta realizar retorno de la mensajería
             IF rg_msj.tip_rechazo IS NULL THEN
                raise_application_error(-20204, 'Motivo de Rechazo para el retorno no puede ser nulo.');
             END IF;
             IF rg_msj.ref_oid IS NULL AND rg_msj.ind_valor = 'S' THEN
                raise_application_error(-20205, 'OID y/o Motivo de Rechazo para el retorno no puede(n) ser nulo(s).');
             END IF;
             pas_snp.pr_pro_msj_rechazado( rg_msj );
             IF pas_snp.fu_obt_cod_error <> 0 THEN
                raise_application_error(-20206, pas_snp.fu_obt_msj_error);
             END IF;
             rg_msj.estado := 'R';
             pas_snp.pr_set_transferencias( rg_msj );
             IF pas_snp.fu_obt_cod_error <> 0 THEN
                raise_application_error(-20207, pas_snp.fu_obt_msj_error);
             END IF;
             v_asunto := 'Transacción Reversada - SNP.';
             v_texto  := 'Se ha reversado la operación. ';
          ELSE
            IF p_cod_tip_circuito NOT IN(911,912) THEN
               --Si no es un MT Recibido REVERSADO, entonces cancela el MT y cierra el Circuito
               rg_msj.estado := 'C';
               pas_snp.pr_set_transferencias(rg_msj);
               v_asunto := 'Transacción Cancelada - SNP.';
               v_texto  := 'Se ha cancelado la operación.';
            ELSE
               raise_application_error(-20208, 'No puede seleccionar este tipo de causal para este circuito.' );
            END IF;
          END IF;
          v_dir_correo := pas_snp.g_gru_dir_correo;
        END IF;
        IF pas_snp.fu_obt_cod_error = 0 AND
           v_dir_correo IS NOT NULL
        THEN
           it_mail.mail( fug_obt_dir_correo,
                         v_dir_correo,
                         v_asunto,
                         v_texto||'A continuación los datos de la mensajería:' || chr(10) ||
                         'Nro. Operación : '||v_referencia || chr(10) ||
                         'Fecha Valor    : '||to_char(rg_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                         'Tipo Operación : '||pas_snp.fu_obt_des_tip_operacion( rg_msj.cod_msj_swift,
                                                                                rg_msj.cod_tip_operacion,
                                                                                rg_msj.cod_sub_tip_operacion
                                                                              ) || chr(10) ||
                         'Moneda         : '||rg_msj.cod_moneda || chr(10) ||
                         'Monto          : '||trim(to_char(rg_msj.monto,'999,999,999,999,999.99')) || chr(10) ||
                         'Usuario        : '||fue_obt_nom_usuario(USER)|| chr(10) ||
                         'Motivo         : '||p_comentario || chr(10) ||
                         chr(10)||'Atentamente.'
                       );
        END IF;
     END IF;
   EXCEPTION
     WHEN others THEN
       raise;
   END lp_tip_acc_cancelar;

   --Procedimiento interno para el tipo de acción Rechazar.
  PROCEDURE lp_tip_acc_rechazar( p_cod_tip_circuito in     wf_circuitos.cod_tip_circuito%type,
                                 p_cod_tip_tarea    in     wf_cir_tareas.cod_tip_tarea%type,
                                 rg_msj             in out pas_snp.rg_msj
                               ) is

   BEGIN
     IF (p_cod_tip_tarea <> 0 OR (fug_obt_pardinamico('SIB_SNP_EJE_CIRCUITO')='S' AND p_cod_tip_tarea <> 0)) THEN
        rg_msj.estado := 'S';
        pas_snp.pr_set_transferencias( rg_msj );
        IF pas_snp.fu_obt_cod_error <> 0 THEN
           raise_application_error( -20300, pas_snp.fu_obt_msj_error );
        END IF;
        v_asunto := 'Transacción Rechazada - SNP.';
        v_texto  := 'Se ha rechazado la operación. ';
        IF pas_snp.fu_val_es_enviado( rg_msj ) THEN
           v_dir_correo := fug_obt_dir_mail_usu(nvl(rg_msj.cod_usuario,rg_msj.usu_insercion));
        ELSE
           v_dir_correo := pas_snp.g_gru_dir_correo;
        END IF;
        IF pas_snp.fu_obt_cod_error = 0 AND
           v_dir_correo IS NOT NULL
        THEN
           it_mail.mail( fug_obt_dir_correo,
                         v_dir_correo,
                         v_asunto,
                         v_texto||'A continuación los datos de la mensajería:' || chr(10) ||
                         'Nro. Operación : '||v_referencia || chr(10) ||
                         'Fecha Valor    : '||to_char(rg_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                         'Tipo Operación : '||pas_snp.fu_obt_des_tip_operacion( rg_msj.cod_msj_swift,
                                                                                rg_msj.cod_tip_operacion,
                                                                                rg_msj.cod_sub_tip_operacion
                                                                              ) || chr(10) ||
                         'Moneda         : '||rg_msj.cod_moneda || chr(10) ||
                         'Monto          : '||trim(to_char(rg_msj.monto,'999,999,999,999,999.99')) || chr(10) ||
                         'Usuario        : '||fue_obt_nom_usuario(USER)|| chr(10) ||
                         'Motivo         : '||p_comentario || chr(10) ||
                         chr(10)||'Atentamente.'
                       );
        END IF;
     END IF;
     
   EXCEPTION
     WHEN others THEN
       raise;
   END lp_tip_acc_rechazar;
BEGIN
  /* ===================  S E C C I Ó N   P R I N C I P A L   D E L   P R O C E D I M I E N T O  =================== */

  /* Ejecutar la lógica sólo si el DET_SQL de la tarea pendiente en el circuito se está procesando desde el WMSEGUIM */
  IF pae_cnf.g_programa = 'WMSEGUIM' THEN
     pas_snp.g_lugar := 'Intentando recuperar datos del circuito '||p_cod_circuito||'. ';
     BEGIN
       SELECT referencia, a.cod_tip_circuito
         INTO v_referencia, v_cod_tip_circuito
         FROM wf_circuitos a, wf_cir_tareas b
        WHERE a.cod_circuito = p_cod_circuito
          AND a.cod_circuito = b.cod_circuito
          AND a.cod_tar_actual = b.cod_tarea;
       --
       pas_snp.g_lugar := 'Intentando recuperar datos de la transferencia '||v_referencia||'. ';
       pas_snp.pr_obt_mensaje(v_referencia, 'N');
       IF pas_snp.fu_obt_cod_error <> 0 THEN
          raise_application_error(-20900, pas_snp.g_lugar||pas_snp.fu_obt_msj_error);
       ELSE -- No tiene ERRORES
          rg_msj := pas_snp.fu_obt_reg_transferencias;
          pas_snp.pr_ini_registros;
       END IF;
       --
     EXCEPTION
       WHEN no_data_found THEN
         raise_application_error(-20901, pas_snp.g_lugar||'Datos inexistentes');
       WHEN others THEN
         if sqlcode <= -20000 then
            raise;
         else
           raise_application_error(-20902, pas_snp.g_lugar||'Error: '||sqlerrm);
         end if;
     END;

     IF pas_snp.fu_obt_cod_error <> 0 THEN
        raise_application_error(-20903, pas_snp.g_lugar||pas_snp.fu_obt_msj_error);
     ELSE --No tiene ERRORES
       pas_snp.g_lugar := 'Intentando ejecutar la acción correspondiente para la transferencia '||v_referencia||'. ';
       IF p_tip_accion = 'A' THEN
          pas_snp.g_lugar := 'Intentando APROBAR el tipo de tarea '||p_cod_tip_tarea||' para el circuito '||p_cod_circuito||'. ';
          lp_tip_acc_aprobar(v_cod_tip_circuito, p_cod_tip_tarea, rg_msj);
       ELSIF p_tip_accion = 'R' THEN
          pas_snp.g_lugar := 'Intentando RECHAZAR el tipo de tarea '||p_cod_tip_tarea||' para el circuito '||p_cod_circuito||'. ';
          lp_tip_acc_rechazar(v_cod_tip_circuito, p_cod_tip_tarea, rg_msj);
       ELSIF p_tip_accion = 'C' THEN
          pas_snp.g_lugar := 'Intentando CANCELAR el tipo de tarea '||p_cod_tip_tarea||' para el circuito '||p_cod_circuito||'. ';
          lp_tip_acc_cancelar(v_cod_tip_circuito, p_cod_tip_tarea, p_cod_cau_rechazo, rg_msj);
       ELSE
          raise_application_error(-20904,pas_snp.g_lugar||'Tipo de acción inexistente.');
       END IF;
     END IF;
 END IF;

EXCEPTION
   WHEN others THEN
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20905, 'Error en PRS_SNP_EJE_CIRCUITO: '||pas_snp.g_lugar||sqlerrm);
     end if;
END;
/

