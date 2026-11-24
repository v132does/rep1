CREATE OR REPLACE PROCEDURE IT.PWG_ANU_CLAVES IS
/*
Este procedimiento fue creado para anular automáticamente las claves generadas y no utilizadas para el Homebanking,
los filtros aplicados son:
  - Claves en Estado "Nuevo"   => Anulación al final del día en todos los casos.-
  - Claves en Estado "Impreso" => Para Personas Físicas al final del día.-
  - Claves en Estado "Impreso" => Para Personas Jurídicas a las 72 hs. de haber sido impresos.-
  - Claves en Estado "Activo"  => En todos los casos Anular a las 48hs. de activado.-
*/

--DECLARE
    v_lugar varchar2(50);
    --> Variables de Ge_clientes
    v_cont1  number := 0;
    v_cont2  number := 0;
    v_cont3  number := 0;
    v_cont4  number := 0;
    v_cont5  number := 0;
    v_total  number := 0;
    --> Variables de Bw_ope_claves
    v_cont1T number := 0;
    v_cont2T number := 0;
    v_cont3T number := 0;
    v_cont4T number := 0;
    v_cont5T number := 0;
    v_totalT number := 0;
    v_dia_act_pj number(10):= nvl(fug_obt_pardinamico('HB_DPACA_ACT_PJ'),99) ;


    --> Cursor de Claves en Estado "Activo". A las 48 hs. de activado se anulan en todos los casos.-
    cursor cla_acceso1 is
           --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
      /*Select a.fec_est_clave,a.cod_persona, a.est_clave, 'A' as tipo
        From ge_clientes a
       Where a.est_clave = 'A'
         and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) > 2
         and a.fec_ult_acceso Is Null*/
      Select a.fec_est_clave,a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
        From bw_ope_claves a
       Where a.est_clave = 'A'
         and ((a.nro_lote is not null and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_MASIVAS')) 
             or (a.nro_lote is null and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_ACTIVAS')))
         and a.fec_ult_acceso Is Null
         and a.tip_clave = 'A'
         and not exists (select 1
                           from bw_gen_claves c
                          where c.nro_lote_gen is not null
                            and c.nro_lote_gen = a.nro_lote
                            and c.cod_persona = a.cod_persona)
      Union ALL --Claves generadas masivamente (BSEVOCORE-934)
      Select a.fec_est_clave, a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
        From bw_ope_claves a
       Where a.est_clave = 'A'
         and a.fec_ult_acceso Is Null
         and a.tip_clave = 'A'
         and a.nro_lote is not null
         and (Trunc(Sysdate) - Trunc(a.fec_est_clave)) >= fug_obt_pardinamico('HB_DIA_GRA_CLA')
         and exists (select 1
                       from bw_gen_claves c
                      where c.nro_lote_gen is not null
                        and c.nro_lote_gen = a.nro_lote
                        and c.cod_persona = a.cod_persona)
      Union All
      Select a.fec_est_clave,a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
        From bw_ope_claves a
       Where a.est_clave = 'A'
         and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACT_ACTIVAS')
         and a.fec_ult_acceso Is Null
         and a.tip_clave = 'T';

    --> Cursor de Claves en Estado "Impreso". Solo para Personas Físicas al Final del Día.-
    cursor cla_acceso2 is
            --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
          /*Select a.cod_persona, a.est_clave, 'A' as tipo
            From ge_clientes a, ba_personas b
           Where a.est_clave   = 'I'
             and a.cod_persona = b.cod_persona
             and b.tipo        = 'F' --Personas Fisicas que NO tengan vinculos con Entes Jurídicos
             and Not Exists ( Select 1
                              From   ba_vinculos v , ba_personas pp
                              Where  b.cod_persona = v.cod_per_vinculo
                                and  v.cod_persona = pp.cod_persona
                                and  pp.tipo       = 'J'
                                and  v.cod_perfil  Is Not Null ) */
          Select a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where (a.est_clave   = 'I' or a.est_clave = 'P')
             and a.cod_per_vinculada is null
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_IMP_PF')
             and a.tip_clave = 'A'
          Union All
          Select a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where (a.est_clave   = 'I' or a.est_clave = 'P')
             and a.cod_per_vinculada is null
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACT_IMP_PF')
             and a.tip_clave = 'T';

    --> Cursor de Claves en Estado "Impreso". Solo Para Personas Juridicas a las 72 hs. de haber sido impresos
    cursor cla_acceso3 is
             --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
           /*Select a.cod_persona, a.est_clave, 'A' as tipo
            From ge_clientes a, ba_personas b
           Where a.est_clave   = 'I'
             and a.cod_persona = b.cod_persona
             and b.tipo        = 'F' --Personas Físicas Vinculadas a Entidades
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >  (PAG_CAL.FU_OBT_FEC_SIG_HAB(trunc(sysdate), 1, 3)   - trunc(sysdate))
             and Exists ( Select 1
                          From   ba_vinculos v , ba_personas pp
                          Where  b.cod_persona = v.cod_per_vinculo
                            and  v.cod_persona = pp.cod_persona
                            and  pp.tipo       = 'J'
                            and  v.cod_perfil  Is Not Null )*/
           Select a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where (a.est_clave   = 'I' or a.est_clave = 'P')
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_IMP_PJ')
             and a.cod_per_vinculada Is Not Null
             and a.tip_clave = 'A'
           Union All
           Select a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where (a.est_clave   = 'I' or a.est_clave = 'P')
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACT_IMP_PJ')
             and a.cod_per_vinculada Is Not Null
             and a.tip_clave = 'T';

    --> Cursor de Claves en Estado "Nuevo". Anulación al final del día en todos los casos
    Cursor cla_acceso4 Is
            --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
          /*Select a.fec_est_clave,a.cod_persona, a.est_clave, 'A' as tipo
            From ge_clientes a
           Where a.est_clave = 'N'*/
          Select a.fec_est_clave,a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where a.est_clave = 'N'
             and a.tip_clave = 'A'
             and ((a.nro_lote is not null and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_MASIVAS'))
                 or (a.nro_lote is null and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACA_NUEVO')))
          Union All
          Select a.fec_est_clave,a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where a.est_clave = 'N'
             and a.tip_clave = 'T'
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= fug_obt_pardinamico('HB_DPACT_NUEVO');


    --> Cursor de Claves de "Acceso" en Estado "Activo". Solo Para Personas Juridicas a las 48 hs.(Parametrizable) de haber sido activadas
    cursor cla_acceso5 is
         Select a.cod_persona, a.est_clave, a.tip_clave, a.cod_per_vinculada
            From bw_ope_claves a
           Where (a.est_clave   = 'A' ) --Solo que quedaron activas
             and (Trunc(Sysdate)- Trunc(a.fec_est_clave) ) >= v_dia_act_pj
             and a.cod_per_vinculada Is Not Null
             and a.tip_clave = 'A'; --Solo de Acceso
  
BEGIN
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1 ; END;

      --> Claves en Estado "Activo" -> A las 48 hs. de activado, en todos los casos
      v_cont1  := 0;
      v_cont1T := 0;
      v_lugar  := 'cla_acceso1';
      For d In cla_acceso1 Loop
              --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
            /* If d.tipo = 'A' Then  --> Claves

                Update ge_clientes a
                   Set a.est_clave   = 'X'
                 Where a.cod_persona = d.cod_persona;
                v_cont1 := nvl(v_cont1,0) + 1;

             Else                  --> Tansaccionales*/

                Update bw_ope_claves a
                   Set a.est_clave   = 'X',
                       a.fec_est_clave = SYSDATE
                 Where a.cod_persona = d.cod_persona
                   and nvl(a.cod_per_vinculada,-1) = nvl(d.cod_per_vinculada,-1)
                   and a.tip_clave = d.tip_clave;

                   if d.tip_clave = 'A' then
                      v_cont1 := nvl(v_cont1,0) + 1;
                   else
                      v_cont1T := nvl(v_cont1T,0) + 1;
                   end if;

             /*End If;*/
      End Loop;

      --> Claves en Estado "Impreso" -> Para Personas Físicas al final del día
      v_cont2  := 0;
      v_cont2T := 0;
      v_lugar  := 'cla_acceso2';
      For d In cla_acceso2 Loop
            --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
          /*If d.tipo = 'A' Then --> Claves

              Update ge_clientes a
                 Set a.est_clave   = 'X'
               Where a.cod_persona = d.cod_persona;
              v_cont2 := nvl(v_cont2,0) + 1;

          Else                --> Transaccionales*/

              Update bw_ope_claves a
                 Set a.est_clave   = 'X',
                     a.fec_est_clave = SYSDATE
               Where a.cod_persona = d.cod_persona
                 and nvl(a.cod_per_vinculada,-1) = nvl(d.cod_per_vinculada,-1)
                 and a.tip_clave = d.tip_clave;

                   if d.tip_clave = 'A' then
                       v_cont2 := nvl(v_cont2,0) + 1;
                   else
                       v_cont2T := nvl(v_cont2T,0) + 1;
                   end if;

          /*End If;*/
      End Loop;

      --> Claves en Estado "Impreso". Para Personas Jurídicas a las 72 hs. de haber Sido Impresos.-
      v_cont3  := 0;
      v_cont3T := 0;
      v_lugar  := 'cla_acceso3';
      For d In cla_acceso3 Loop
           --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
         /* If d.tipo = 'A' Then --> Claves

              Update ge_clientes a
                 Set a.est_clave   = 'X'
               Where a.cod_persona = d.cod_persona;
              v_cont3 := nvl(v_cont3,0) + 1;

           Else                --> Transaccionales*/

              Update bw_ope_claves a
                 Set a.est_clave   = 'X',
                     a.fec_est_clave = SYSDATE
               Where a.cod_persona = d.cod_persona
                 and nvl(a.cod_per_vinculada,-1) = nvl(d.cod_per_vinculada,-1)
                 and a.tip_clave = d.tip_clave;


                   if d.tip_clave = 'A' then
                      v_cont3 := nvl(v_cont3,0) + 1;
                   else
                      v_cont3T := nvl(v_cont3T,0) + 1;
                   end if;

           /*End If;*/
      End Loop;

      --> Claves en Estado "Nuevo" -> Anulación al final del día en todos los casos
      v_cont4  := 0;
      v_cont4T := 0;
      v_lugar  := 'cla_acceso4';
      For d In cla_acceso4 Loop
             --19-07-2013-EC-GC: Modificado por los cambios de seguridad (tip_clave)
           /*If d.tipo = 'A' Then --> Claves

                Update ge_clientes a
                   Set a.est_clave   = 'X'
                 Where a.cod_persona = d.cod_persona;
                v_cont4 := nvl(v_cont4,0) + 1;

           Else                 --> Transaccionales*/

                Update bw_ope_claves a
                   Set a.est_clave   = 'X',
                       a.fec_est_clave = SYSDATE
                 Where a.cod_persona = d.cod_persona
                   and nvl(a.cod_per_vinculada,-1) = nvl(d.cod_per_vinculada,-1)
                   and a.tip_clave = d.tip_clave;

                   if d.tip_clave = 'A' then
                      v_cont4 := nvl(v_cont4,0) + 1;
                   else
                      v_cont4T := nvl(v_cont4T,0) + 1;
                   end if;

          /* End If;*/
      End Loop;
      
      
      
       --> Claves de Acceso en Estado "Activo". Para Personas Jurídicas a las 48 hs. de haber Sido Activadas.-
      v_cont5  := 0;
      v_cont5T := 0;
      v_lugar  := 'cla_acceso5';
      For d In cla_acceso5 Loop
              --Solo Acceso

              Update bw_ope_claves a
                 Set a.est_clave   = 'X',
                     a.fec_est_clave = SYSDATE
               Where a.cod_persona = d.cod_persona
                 and nvl(a.cod_per_vinculada,-1) = nvl(d.cod_per_vinculada,-1)
                 and a.tip_clave = d.tip_clave;


                   if d.tip_clave = 'A' then
                      v_cont5 := nvl(v_cont5,0) + 1;
                   else
                      v_cont5T := nvl(v_cont5T,0) + 1;
                   end if;
      End Loop;
      
      
      
      

      v_total  := nvl(v_cont1 ,0) + nvl(v_cont2 ,0) + nvl(v_cont3 ,0) + nvl(v_cont4 ,0)+ nvl(v_cont5 ,0);
      v_totalT := nvl(v_cont1T,0) + nvl(v_cont2T,0) + nvl(v_cont3T,0) + nvl(v_cont4T,0)+ nvl(v_cont5T,0);

      dbms_output.put_line( 'TOTAL CLAVES ACCESOS ANULADOS : '        || to_char(v_total ));
      dbms_output.put_line( 'TOTAL CLAVES TRANSACCIONALES ANULADOS : '|| to_char(v_totalT));

      COMMIT;

EXCEPTION
     When Others Then
          Raise_Application_Error(-20002 , 'Error En ' || V_Lugar || Sqlerrm);
END;
/

