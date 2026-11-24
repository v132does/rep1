create or replace procedure it.PRG_ACT_DAT_EXT_PERSONAS(p_nro_cuenta varchar2,
                                                     p_fec_ult_extracto date,
                                                     p_lugar varchar2,
                                                     p_fec_actual date) is
--Actualizar el parámetro FEC_ULT_EXTRACTOS de la tabla ba_per_dat_adicionales que corresponde al cliente.
     --CROGENEXT-13 Sergio Servín 06/08/2014

       v_fec_ult_extracto date /*:= p_fec_ult_extracto*/;
       v_frec_extracto ba_per_dat_adicionales.val_parametro%type;
       v_cod_persona ba_personas.cod_persona%type := fug_obt_cli_principal(p_nro_cuenta,'P');
       v_lugar varchar2(500) := p_lugar;
       v_fec_actual date := p_fec_actual;

     BEGIN
     --pre_cam_for_fecha('DD/MM/YYYY');

         --BUSCAMOS FEC_ULT_EXTRACTO--
              BEGIN
                SELECT to_date(T.VAL_PARAMETRO,'dd/mm/yyyy')
                INTO v_fec_ult_extracto
                FROM BA_PER_DAT_ADICIONALES T
                WHERE T.COD_PERSONA = V_COD_PERSONA
                AND   T.PARAMETRO = 'FEC_ULT_EXTRACTOS';
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    --raise_application_error(-20000,v_lugar||'-- No se encuentra fecha de último extracto - ');
                  v_fec_ult_extracto := null;
                  WHEN OTHERS THEN
                    raise_application_error(-20000,v_lugar||'- Error- No se encuentra fecha de último extracto - '||sqlerrm);
              END;


         --BUSCAMOS LA FRECUENCIA DE EXTRACTO--
              BEGIN
                SELECT T.VAL_PARAMETRO
                INTO v_frec_extracto
                FROM BA_PER_DAT_ADICIONALES T
                WHERE T.COD_PERSONA = V_COD_PERSONA
                AND   T.PARAMETRO = 'FRE_EXTRACTOS';
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    --raise_application_error(-20000,v_lugar||'-- No se encuentra FRECUECIA de extracto - ');
                  v_frec_extracto := NULL;
                  WHEN OTHERS THEN
                    raise_application_error(-20000,v_lugar||'- Error al buscar la FRECUECIA de extracto - '||sqlerrm);
              END;
       if v_frec_extracto is not null then
            if v_fec_ult_extracto is not null then

                  --mensual
                  IF nvl(v_frec_extracto,'M') = 'M' THEN

                        BEGIN
                          UPDATE BA_PER_DAT_ADICIONALES B SET B.VAL_PARAMETRO = to_char(p_fec_ult_extracto,'DD/MM/YYYY')
                          WHERE B.COD_PERSONA = V_COD_PERSONA
                          AND   B.PARAMETRO = 'FEC_ULT_EXTRACTOS';
                        EXCEPTION
                          WHEN OTHERS THEN
                            raise_application_error(-20000,v_lugar||'- Error Al actualizar la fecha de último extracto - '||sqlerrm);
                        END;

                  --trimestral
                  ELSIF v_frec_extracto = 'T' THEN
                    --controla que la fecha del extracto corresponda al último día habil de un mes trimestral
                    IF v_fec_actual IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(v_fec_ult_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(v_fec_ult_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(v_fec_ult_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(v_fec_ult_extracto,'YYYY'),'DD/MM/YYYY')),-1,2)) THEN
                        BEGIN
                          UPDATE BA_PER_DAT_ADICIONALES B SET B.VAL_PARAMETRO = to_char(p_fec_ult_extracto,'DD/MM/YYYY')
                          WHERE B.COD_PERSONA = V_COD_PERSONA
                          AND   B.PARAMETRO = 'FEC_ULT_EXTRACTOS';
                        EXCEPTION
                          WHEN OTHERS THEN
                            raise_application_error(-20000,v_lugar||'- Error Al actualizar la fecha de último extracto - '||sqlerrm);
                        END;

                    END IF;

                  END IF;

             --insertamos nuevo registro si es que no tiene último extracto
             else
                  IF nvl(v_frec_extracto,'M') = 'M' THEN

                     begin
                       insert into BA_PER_DAT_ADICIONALES(COD_PERSONA,PARAMETRO, VAL_PARAMETRO)
                              VALUES(V_COD_PERSONA,'FEC_ULT_EXTRACTOS',to_char(v_fec_actual,'DD/MM/YYYY'));
                       exception
                       when others then
                         raise_application_error(-20000,v_lugar||'- Error al insertar nueva fecha de útlimo extracto - '||sqlerrm);
                     end;
                  elsif v_frec_extracto = 'T' THEN
                      IF v_fec_actual IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(v_fec_actual,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(v_fec_actual,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(v_fec_actual,'YYYY'),'DD/MM/YYYY')),-1,2),
                                              pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(v_fec_actual,'YYYY'),'DD/MM/YYYY')),-1,2)) THEN
                           begin
                             insert into BA_PER_DAT_ADICIONALES(COD_PERSONA,PARAMETRO, VAL_PARAMETRO)
                                    VALUES(V_COD_PERSONA,'FEC_ULT_EXTRACTOS',to_char(v_fec_actual,'DD/MM/YYYY'));
                             exception
                             when others then
                               raise_application_error(-20000,v_lugar||'- Error al insertar nueva fecha de útlimo extracto - '||sqlerrm);
                           end;                      
                      
                      
                      
                      
                      end if;
                  
                  
                  
                  end if;
            END IF;
      else
           --inserta la frecuencia mensual (por defecto)
           begin
           insert into BA_PER_DAT_ADICIONALES(COD_PERSONA,PARAMETRO, VAL_PARAMETRO)
                     VALUES(V_COD_PERSONA,'FRE_EXTRACTOS','M');
           exception
           when others then
            raise_application_error(-20000,v_lugar||'- Error al insertar nueva fecha de útlimo extracto - '||sqlerrm);
           end;
           
           --inserta la fecha del extracto de la fecha actual.(por defecto.)
           begin
           insert into BA_PER_DAT_ADICIONALES(COD_PERSONA,PARAMETRO, VAL_PARAMETRO)
            VALUES(V_COD_PERSONA,'FEC_ULT_EXTRACTOS',to_char(v_fec_actual,'DD/MM/YYYY'));
           exception
           when others then
           raise_application_error(-20000,v_lugar||'- Error al insertar nueva fecha de útlimo extracto - '||sqlerrm);
           end;


      end if;

end PRG_ACT_DAT_EXT_PERSONAS;
/

