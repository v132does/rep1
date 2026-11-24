CREATE OR REPLACE PROCEDURE IT.PRG_DIS_TAS_PERSONALIZADAS IS
    v_existe      varchar2(1)  := 'N';
    v_insertar    varchar2(1)  := 'S';
    v_tipo        ge_tasas.tipo%type;
    v_hora        VARCHAR2(8) := to_char(sysdate,'HH24:MM:SS');
    v_cod_persona ba_personas.cod_persona%type;
    v_cod_moneda  ge_cuentas.cod_moneda%type;

    -- Cursor de Empresas a Parametrizar
    Cursor dat_excel is
           Select *
           From ge_tas_personalizadas_tmp a;
      
      PROCEDURE INS_LOG (P_HORA         IN VARCHAR2,
                         P_COD_ENTE     IN NUMBER  ,
                         P_NRO_CUENTA   IN VARCHAR2,
                         P_COD_TASA     IN NUMBER  ,
                         P_COD_PERSONA  IN VARCHAR2,
                         P_FEC_VIGENCIA IN DATE    ,
                         P_OBSERVACION  IN VARCHAR2) IS
           Begin
                insert into ge_tas_personalizadas_dat(hora          ,
                                                      nro_cuenta    ,
                                                      cod_ente      ,
                                                      cod_tasa      ,
                                                      cod_persona   ,
                                                      fec_vigencia  ,
                                                      observacion   )
                                               values(P_HORA        ,
                                                      P_COD_ENTE    ,
                                                      P_NRO_CUENTA  ,
                                                      P_COD_TASA    ,
                                                      P_COD_PERSONA ,
                                                      P_FEC_VIGENCIA,
                                                      P_OBSERVACION );
            Exception
                when others then
                     raise_application_error(-20000,'Error al Generar Log '||sqlerrm);
            End;
BEGIN
     BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
     For i in dat_excel loop
         v_cod_persona := fug_obt_cli_principal(i.nro_cuenta);
         v_cod_moneda  := fug_obt_mon_cta(i.nro_cuenta);
          v_insertar   := 'S';
         --> Verificar que la cuenta se encuetre vigente.-
         If FUG_OBT_SIT_CUENTA(i.nro_cuenta) = 'N' Then
            --raise_application_error(-20000,'La Cuenta '||i.nro_cuenta||' NO se encutra Activa');
            INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, 'La Cuenta NO se Encuentra ACTIVA');
            v_insertar := 'N';
         End If;
         
         --> Verificar que la fecha de puesta en vigencia NO sea previa a la actual.- 
         If i.fec_vigencia < pag_cal.FU_OBT_FEC_ACTUAL(1) then
            raise_application_error(-20000,'La Fecha de Puesta en vigencia No puede ser anterior a la actual. Ente: '||i.cod_ente);
         End If;
         
         --> Verificar que la tasa a distribuir sea solamente Fija y que exista en el Core.-
         Begin
             Select a.tipo 
               into v_tipo
               from ge_tasas a
              where a.cod_tasa = i.cod_tasa;
         Exception
             when no_data_found then
                  raise_application_error(-20000,'Tasa '||i.cod_tasa||' Inexistente.');
         End;
         If v_tipo != 'F' then
            raise_application_error(-20000,'Solo puede importar tasas de tipo Fija. Tasa: '||i.cod_tasa);
         End If;
         
         --> Verificar que el tipo de valor este bien aplicado.-
         if (i.val_minimo is not null or i.val_maximo is not null or i.val_tasa is not null) and i.val_extension is not null then
               raise_application_error(-20000,'Debe ingresar Valor de Tarifa y/o Mínimo y/o Máximo o Spread. Ente: '||i.cod_ente);
         Elsif i.val_minimo is null and i.val_maximo is null and i.val_tasa is null and i.val_extension is null then
               raise_application_error(-20000,'Debe ingresar por lo menos UN Valor de Tarifa y  Mínimo y Máximo o Spread. Ente: '||i.cod_ente);
         End If;
         
         --> Verificar que el Porcentaje tenga los valores correctos
         If i.val_extension < 0 or i.val_extension > 100 then
             raise_application_error(-20000,'El Valor Porcentaje debe corresponder entre 0(Cero) y 100 (Cien). Ente: '||i.cod_ente);
         End If;
         
         --> Verificar que los Valores No sean Negativos.-
         If i.val_minimo < 0 or i.val_maximo < 0 or i.val_tasa < 0 then
             raise_application_error(-20000,'No puede insertar valores en Negativo. Ente: '||i.cod_ente);
         End If;
         
         --> Verficar que la Fecha de Vencimiento no sea inferior a la de Vigencia
         If i.fec_vencimiento < i.fec_vigencia Then
            raise_application_error(-20000,'La Fecha de Vencimiento NO debe ser Inferior a la Puesta en Vigencia. Ente: '||i.cod_ente);
         End If;
         
         --> Verificar si el cliente ya tiene asignada una tasa Similar Vigente.-
          Begin
              Select distinct('S') --> Verifica por Cuenta
                into v_existe 
                from ge_tas_fechas a 
               where a.cod_tasa        = i.cod_tasa
                 and a.nro_cuenta      = i.nro_cuenta
                 and a.fec_vencimiento >= pag_cal.fu_obt_fec_actual(1);
               INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, 'Cuenta Con Tasa Similar Vigente');
               v_insertar := 'N';
          Exception
             When no_data_found then
                  Begin
                      Select distinct('S') --> Verifica por Moneda Similar a la Cuenta
                        into v_existe 
                        from ge_tas_fechas a 
                       where a.cod_tasa        = i.cod_tasa
                         and a.cod_persona     = v_cod_persona
                         and a.cod_moneda      = v_cod_moneda
                         and a.fec_vencimiento >= pag_cal.fu_obt_fec_actual(1);
                       INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, 'Cliente con Tasa Similar Vigente para la misma Moneda: '||v_cod_moneda||' de la Cuenta '||i.nro_cuenta);
                       v_insertar := 'N';
                  Exception
                      When No_data_Found then
                           Begin
                               Select distinct('S') --> Verifica por Código de Persona
                                 into v_existe 
                                 from ge_tas_fechas a 
                                where a.cod_tasa        = i.cod_tasa
                                  and a.cod_persona     = v_cod_persona
                                  and a.fec_vencimiento >= pag_cal.fu_obt_fec_actual(1);
                                INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, 'Cliente con Tasa Similar Vigente para TODOS LOS PRODUCTOS');
                                v_insertar := 'N';
                            Exception
                               When No_data_found then
                                    v_existe := 'N';
                               When Others Then
                                    INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, sqlerrm);
                                    v_insertar := 'N';
                            End;
                      When Others Then
                           INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, sqlerrm);
                           v_insertar := 'N';
                  End;
             When Others Then
                  INS_LOG(v_hora,i.nro_cuenta, i.cod_ente, i.cod_tasa, v_cod_persona, i.fec_vigencia, sqlerrm);
                  v_insertar := 'N';
          End;
          
          --> Aplicar la Tasa
          If  v_existe = 'N' and v_insertar = 'S' Then
              Begin
                  Insert into ge_tas_fechas(cod_tasa         ,
                                            --cod_persona      ,
                                            fec_vigencia     ,
                                            cod_moneda       , 
                                            nro_cuenta       ,                                            
                                            aplicar          ,
                                            val_minimo       ,
                                            val_maximo       ,
                                            val_tasa         ,
                                            val_extension    ,
                                            fec_vencimiento  ,
                                            observaciones    )
                                     values(i.cod_tasa       ,
                                            --v_cod_persona    ,
                                            i.fec_vigencia   ,
                                            v_cod_moneda     ,
                                            i.nro_cuenta     ,
                                            'ST'             ,
                                            i.val_minimo     ,
                                            i.val_maximo     ,
                                            i.val_tasa       ,
                                            i.val_extension  ,
                                            i.fec_vencimiento,
                                            'Imp.Masiva.Ente:'||i.cod_ente||i.observacion    );

              Exception
                  When Others Then
                       raise_application_error(-20000,'Error al Insertar Tasas Personalizadas '||sqlerrm);
              End;
              
          End If;
     End Loop;
     COMMIT;
EXCEPTION
     When Others Then
          raise_application_error(-20000, 'Error '||sqlerrm);
END;
/

