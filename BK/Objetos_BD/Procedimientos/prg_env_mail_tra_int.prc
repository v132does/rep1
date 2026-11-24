CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_TRA_INT(p_nro_documento IN ge_movimientos.nro_documento%TYPE) IS
  v_dir_cor_usu_comex varchar2(100) := fug_obt_pardinamico('DIR_MAI_COMEX');
  v_dir_correo_ges    ba_usuarios.dir_correo%type;
  v_cod_gestor        ba_personas.cod_persona%type;
  v_dir_correo_ent    ba_usuarios.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_CMX_RTTE');--'comex@bbva.com.py';
  v_archivo           blob;
  v_nom_archivo       varchar2(100);
  p_html              long;
  v_tipo              varchar2(10);
  v_nro_documento     varchar2(30);
  v_nro_ord_dna       varchar2(100);
  ---
  v_dir_mail_todos  varchar2(400);
  v_horIni          varchar(10);
  v_horFin          varchar(10);
  v_error           varchar2(4000);
  --variables de lc_transferencias
  v_usu_insercion       lc_transferencias.usu_insercion%TYPE;
  v_cod_per_solicitante lc_transferencias.cod_per_solicitante%TYPE;
  v_nro_operacion       lc_transferencias.nro_operacion%TYPE;
  v_nro_referencia      lc_transferencias.nro_referencia%TYPE;
  v_nro_ord_pag_dna     lc_transferencias.nro_ord_pag_dna%TYPE;
  v_nom_solicitante     lc_transferencias.nom_solicitante%TYPE;
  v_monto               lc_transferencias.monto%TYPE;
  v_cod_moneda          lc_transferencias.cod_moneda%TYPE;
  v_plazo               lc_transferencias.plazo%TYPE;
  v_cod_banco           lc_transferencias.cod_banco%TYPE;
  v_nom_banco           lc_transferencias.nom_banco%TYPE;
  v_cod_swi_banco       lc_transferencias.cod_swi_banco%TYPE;
  v_nom_beneficiario    lc_transferencias.nom_beneficiario%TYPE;
  v_nro_cta_referencia  lc_transferencias.nro_cta_referencia%TYPE;
  v_tip_cargo           lc_transferencias.tip_cargo%TYPE;
  v_nro_operacion2      lc_transferencias.nro_operacion2%TYPE;
  v_nro_cta_debito      lc_transferencias.nro_cta_debito%TYPE;
BEGIN
	BEGIN
		SELECT lt.usu_insercion, lt.cod_per_solicitante, lt.nro_operacion, lt.nro_referencia,
				lt.nro_ord_pag_dna, lt.nom_solicitante, lt.monto, lt.cod_moneda, lt.plazo, lt.cod_banco,
				lt.nom_banco, lt.cod_swi_banco, lt.nom_beneficiario, lt.nro_cta_referencia, lt.tip_cargo,
				lt.nro_operacion2, lt.nro_cta_debito
		INTO v_usu_insercion, v_cod_per_solicitante, v_nro_operacion, v_nro_referencia,
			v_nro_ord_pag_dna, v_nom_solicitante, v_monto, v_cod_moneda, v_plazo, v_cod_banco,
			v_nom_banco, v_cod_swi_banco, v_nom_beneficiario, v_nro_cta_referencia, v_tip_cargo,
			v_nro_operacion2, v_nro_cta_debito
		FROM lc_transferencias lt
		WHERE lt.nro_operacion = p_nro_documento OR lt.nro_operacion2 = p_nro_documento
		ORDER BY lt.fec_insercion DESC;
	EXCEPTION
		WHEN OTHERS THEN
			v_horIni := TO_CHAR(sysdate,'hh24:mi:ss');
			v_horFin := TO_CHAR(sysdate,'hh24:mi:ss');
			v_error := SQLERRM;
			INSERT INTO ge_log_mail(fec_envio, mensaje, det_error, hor_inicio, hor_fin)
			VALUES (sysdate, 'Informe de TTE - Via HB - Nro de TTE: NRO. DE OPERACION' || p_nro_documento, v_error, v_horIni, v_horFin);
	END;
	
	-- Si el usuario es HBANK se envia mail al gestor y a los de comex
	IF TRIM(UPPER(v_usu_insercion)) = 'HBANK' THEN
		v_archivo := NULL;
		v_nom_archivo := NULL;
		v_tipo := NULL;
		
		BEGIN
			SELECT UPPER(a.tipo)
			INTO v_tipo
			FROM ba_personas a
			WHERE a.cod_persona = v_cod_per_solicitante; /*:new.cod_per_solicitante*/
		EXCEPTION
			WHEN no_data_found THEN
				v_tipo := 'X';
			WHEN OTHERS THEN
				v_tipo := 'X';
		END;
		
		IF v_tipo = 'F' THEN
			BEGIN
				SELECT UTL_COMPRESS.LZ_UNCOMPRESS(a.contenido), rtrim(ltrim(a.nombre))
				INTO v_archivo, v_nom_archivo
				FROM bw_archivos a
				WHERE a.nro_documento= v_nro_operacion /*:new.nro_operacion*/
					AND a.cod_persona= v_cod_per_solicitante /*:new.cod_per_solicitante*/
					AND a.cod_tip_operacion = 227; -- TTE/HB
			EXCEPTION
				WHEN no_data_found THEN
					v_archivo := NULL;
				WHEN OTHERS THEN
					v_archivo := NULL;
			END;
		ELSIF v_tipo = 'J' THEN
			v_nro_documento := null;
			
			BEGIN
				SELECT p.nro_documento
				INTO v_nro_documento
				FROM bw_mov_pendientes p
				WHERE p.cod_per_principal = v_cod_per_solicitante /*:new.cod_per_solicitante*/
					AND p.cod_tip_mensaje = '227'
					AND p.referencia = v_nro_referencia /*:new.nro_referencia*/
					AND trunc(p.fec_insercion) = TRUNC(sysdate);
			EXCEPTION
				WHEN no_data_found THEN
					v_nro_documento := NULL;
				WHEN OTHERS THEN
					v_nro_documento := NULL;
			END;
			
			IF v_nro_documento IS NOT NULL THEN
				-- Buscamos si existe en bw_archivos
				BEGIN
					SELECT UTL_COMPRESS.LZ_UNCOMPRESS(a.contenido), rtrim(ltrim(a.nombre))
					INTO v_archivo, v_nom_archivo
					FROM bw_archivos a
					WHERE a.nro_documento= v_nro_documento
						AND a.cod_persona= v_cod_per_solicitante /*:new.cod_per_solicitante*/
						AND a.cod_tip_operacion=227; -- TTE/HB
				EXCEPTION
					WHEN no_data_found THEN
						v_archivo := NULL;
					WHEN OTHERS THEN
						v_archivo := NULL;
				END;
			ELSE
				v_nro_documento := NULL;
			END IF;
		ELSE
			v_tipo := NULL;
		END IF;
		
		IF v_nro_ord_pag_dna IS NOT NULL THEN
			v_nro_ord_dna := substr('ORDEN PAGO DNA: '||v_nro_ord_pag_dna||chr(10), 1, 100);
		END IF;
		
		IF v_tipo IS NOT NULL THEN
			v_cod_gestor:=null;
			v_dir_correo_ges:=null;
			v_dir_correo_ent := fug_obt_dir_correo;
			v_cod_gestor:= FUG_OBT_COD_USU_OFICIAL(v_cod_per_solicitante);
			
			IF v_cod_gestor IS NOT NULL THEN
				BEGIN
					v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
				EXCEPTION
					WHEN OTHERS THEN
						--Si tuvo problemas que no envíe al gestor, sÃ³lo a comex
						v_dir_correo_ges := null;
				END;
			END IF;
			
			IF v_archivo IS NOT NULL THEN
				IF v_dir_correo_ges IS NOT NULL THEN
					BEGIN
						v_horIni := to_char(sysdate,'hh24:mi:ss');
						p_html := ' Buenas,
                                  <br><br>
                                  Le informamos que se ha ingresado una TTE via HB ingresada por:
                                  <br><br>
                                   CLIENTE: '|| v_nom_solicitante||
                                   '<br>
                                   MONTO: '||v_monto ||
                                   '<br>
                                   MONEDA: '|| v_cod_moneda||
                                   '<br>
                                   FECHA VALOR: '||CASE v_plazo when 0 then 0 when 1 then 24 else 48 end ||
                                   'HS <br>
                                   BANCO DEL BENEF.: '||v_cod_banco||'-'||trim(v_nom_banco) ||
                                   '<br>
                                   SWIFT: '||v_cod_swi_banco ||
                                    '<br>
                                   BENEFICIARIO: ' ||trim(v_nom_beneficiario) ||
                                    '<br>
                                   NRO DE CTA/IBAN: ' ||trim(v_nro_cta_referencia) ||
                                   '<br>
                                   TIPO DE CARGOS: ' ||v_tip_cargo ||
                                   '<br>
                                   NRO. DE OPERACION: '||v_nro_operacion ||
                                   '<br>
                                   NRO. DE OPERACION 2: '||v_nro_operacion2;
						IF v_nro_ord_pag_dna IS NOT NULL THEN
							p_html := p_html  || '<br>
                                               ORDEN PAGO DNA: '||v_nro_ord_pag_dna;
						END IF;
						p_html := p_html  || '<br>
                                               USUARIO: '||v_usu_insercion ||
                                               '<br><br>
                                               Se le envia el presente mail a modo informativo
                                             <br><br>';
						PRG_ENV_MAIL_ADJUNTO(v_dir_correo_ent,
                                             v_dir_correo_ges,
                                             'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia,
                                             p_html,
                                             v_archivo,
                                             v_nom_archivo
                                             );
					EXCEPTION
						WHEN OTHERS THEN
							v_error := sqlerrm;
							v_horFin := to_char(sysdate,'hh24:mi:ss');
							INSERT INTO ge_log_mail(fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
							VALUES (sysdate, v_cod_per_solicitante, substr(NVL(v_dir_correo_ges,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia||chr(10)||p_html, v_error, v_nro_cta_debito, v_horIni, v_horFin);
					END;
				END IF;
				
				IF v_dir_cor_usu_comex IS NOT NULL THEN
					BEGIN
						v_horIni := to_char(sysdate,'hh24:mi:ss');
						p_html := ' Buenas,
                              <br><br>
                              Le informamos que se ha ingresado una TTE via HB ingresada por:
                              <br><br>
                               CLIENTE: '|| v_nom_solicitante||
                               '<br>
                               MONTO: '||v_monto ||
                               '<br>
                               MONEDA: '|| v_cod_moneda||
                               '<br>
                               FECHA VALOR: '||CASE v_plazo when 0 then 0 when 1 then 24 else 48 end ||
                               'HS <br>
                               BANCO DEL BENEF.: '||v_cod_banco||'-'||trim(v_nom_banco) ||
                               '<br>
                               SWIFT: '||v_cod_swi_banco ||
                                '<br>
                               BENEFICIARIO: ' ||trim(v_nom_beneficiario) ||
                                '<br>
                               NRO DE CTA/IBAN: ' ||trim(v_nro_cta_referencia) ||
                               '<br>
                               TIPO DE CARGOS: ' ||v_tip_cargo ||
                               '<br>
                               NRO. DE OPERACION: '||v_nro_operacion ||
                               '<br>
                               NRO. DE OPERACION 2: '||v_nro_operacion2;
						IF v_nro_ord_pag_dna IS NOT NULL THEN
							p_html := p_html  || '<br>
                                           ORDEN PAGO DNA: '||v_nro_ord_pag_dna;
						END IF;
						p_html := p_html  || '<br>
                                           USUARIO: '||v_usu_insercion ||
                                           '<br><br>
                                           Se le envia el presente mail a modo informativo
                                         <br><br>';
						PRG_ENV_MAIL_ADJUNTO(v_dir_correo_ent,
                                         v_dir_cor_usu_comex,
                                         'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia,
                                         p_html,
                                         v_archivo,
                                         v_nom_archivo
                                         );
					EXCEPTION
						WHEN OTHERS THEN
							v_error := sqlerrm;
							v_horFin := to_char(sysdate,'hh24:mi:ss');
							INSERT INTO ge_log_mail(fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
							VALUES(sysdate, v_cod_per_solicitante, substr(NVL(v_dir_cor_usu_comex,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia||chr(10)||p_html, v_error, v_nro_cta_debito, v_horIni, v_horFin);
					END;
				END IF;
			ELSE
				BEGIN
					v_dir_mail_todos := NULL;
					
					IF v_dir_correo_ges IS NOT NULL AND v_dir_cor_usu_comex IS NOT NULL THEN
						v_dir_mail_todos :=  v_dir_correo_ges||';'||v_dir_cor_usu_comex;
					ELSIF v_dir_correo_ges IS NULL AND v_dir_cor_usu_comex IS NOT NULL THEN
						v_dir_mail_todos :=  v_dir_cor_usu_comex;
					END IF;
					
					IF v_dir_mail_todos IS NOT NULL THEN
						v_horIni := to_char(sysdate,'hh24:mi:ss');
						it_mail.mail(v_dir_correo_ent,
                                v_dir_mail_todos,
                                'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia,
                                'Buenas,'|| chr(10)||chr(10)||
                                'Le informamos que se ha ingresado una TTE via HB ingresada por: '|| chr(10)||
                                'CLIENTE: '||v_nom_solicitante || chr(10)||
                                'MONTO: ' ||v_monto || chr(10)||
                                'MONEDA: '|| v_cod_moneda || chr(10)||
                                'FECHA VALOR: '||CASE v_plazo when 0 then 0 when 1 then 24 else 48 end||' HS'||chr(10)||
                                'BANCO DEL BENEF.: '||v_cod_banco||'-'||trim(v_nom_banco)||chr(10)||
                                'SWIFT: '||v_cod_swi_banco||chr(10)||
                                'BENEFICIARIO: ' ||trim(v_nom_beneficiario)||chr(10)||
                                'NRO DE CTA/IBAN:' ||trim(v_nro_cta_referencia)||chr(10)||chr(10)||
                                'TIPO DE CARGOS: ' ||v_tip_cargo||chr(10)||
                                'NRO. DE OPERACION: '||v_nro_operacion||chr(10)||
                                'NRO. DE OPERACION 2: '||v_nro_operacion2||chr(10)||
                                v_nro_ord_dna||
                                'USUARIO: '||v_usu_insercion ||chr(10)|| chr(10)||
                                'Se le envía el presente mail a modo informativo.'
                                );
					END IF;
				EXCEPTION
					WHEN OTHERS THEN
						v_error := sqlerrm;
						v_horFin := to_char(sysdate,'hh24:mi:ss');
						insert into ge_log_mail(fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
						values(sysdate, v_cod_per_solicitante, substr(NVL(v_dir_mail_todos,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||v_nro_referencia||chr(10)||
                                'Buenas,'|| chr(10)||chr(10)||
                                'Le informamos que se ha ingresado una TTE via HB ingresada por: '|| chr(10)||
                                'CLIENTE: '||v_nom_solicitante || chr(10)||
                                'MONTO: ' ||v_monto || chr(10)||
                                'MONEDA: '|| v_cod_moneda || chr(10)||
                                'FECHA VALOR: '||CASE v_plazo when 0 then 0 when 1 then 24 else 48 end||' HS'||chr(10)||
                                'BANCO DEL BENEF.: '||v_cod_banco||'-'||trim(v_nom_banco)||chr(10)||
                                'SWIFT: '||v_cod_swi_banco||chr(10)||
                                'BENEFICIARIO: ' ||trim(v_nom_beneficiario)||chr(10)||
                                'NRO DE CTA/IBAN:' ||trim(v_nro_cta_referencia)||chr(10)||chr(10)||
                                'TIPO DE CARGOS: ' ||v_tip_cargo||chr(10)||
                                'NRO. DE OPERACION: '||v_nro_operacion||chr(10)||
                                'NRO. DE OPERACION 2: '||v_nro_operacion2||chr(10)||
                                v_nro_ord_dna||
                                'USUARIO: '||v_usu_insercion ||chr(10)|| chr(10)||
                                'Se le envía el presente mail a modo informativo.',
                                 v_error, v_nro_cta_debito, v_horIni, v_horFin);
				END;
			END IF;
		END IF;
	END IF;
END;
/

