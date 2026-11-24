CREATE OR REPLACE PROCEDURE IT.prb_obt_rub_area(p_cod_rubro IN VARCHAR2 DEFAULT NULL) IS
   v_cod_rubro  cb_rubros.cod_rubro%Type; --variable donde se asigna el rubro
   v_plsql      Varchar2(1000);           --sentencia sql de las areas
   v_cod_area   Varchar2(4);              --variable donde se asigna el area
   v_can_areas  Number := 0;              --cantidad de areas
   v_con_areas  Number := 0;              --contador de areas
   v_con_areas_resto  Number := 0;
   --contador de areas
   v_sql_rubros Varchar2(4000) := 'Select a.det_sql From ba_consultas a Where a.cod_consulta = ''CD_RUBAREA''';
   -- cursor dinámico
   Type t_tipo_cursor Is Ref Cursor;
   c_cursor    t_tipo_cursor;
   v_sentencia ba_consultas.det_sql%Type; --sentencia sql de los rubros
   --cursor de areas
   Cursor c_areas Is
      Select a.cod_area,
             a.sec_capitulo,
             decode(a.ind_sec_capitulo, 'S', 'In', 'Not In') ind_sec_capitulo,
             a.mod_inf_rubro,
             decode(a.ind_mod_inf_rubro, 'S', 'In', 'Not In') ind_mod_inf_rubro,
             a.plazo,
             decode(a.ind_plazo, 'S', 'In', 'Not In') ind_plazo,
             a.sec_prestamo,
             decode(a.ind_sec_prestamo, 'S', 'In', 'Not In') ind_sec_prestamo
        From cb_rub_areas a
       Where (a.sec_capitulo Is Not Null Or a.mod_inf_rubro Is Not Null Or a.plazo Is Not Null Or
             a.sec_prestamo Is Not Null)
       and a.cod_area not in(1016,1017);---No trae las areas 1016 y 1017---Ajustado por NA 03/10/2013-- incidencia reportada por Patricia Insaurralde

    Cursor c_areas_resto Is---trae solo las areas 1016 y 1017---Ajustado por NA 03/10/2013-- incidencia reportada por Patricia Insaurralde
      Select a.cod_area,
             a.sec_capitulo,
             decode(a.ind_sec_capitulo, 'S', 'In', 'Not In') ind_sec_capitulo,
             a.mod_inf_rubro,
             decode(a.ind_mod_inf_rubro, 'S', 'In', 'Not In') ind_mod_inf_rubro,
             a.plazo,
             decode(a.ind_plazo, 'S', 'In', 'Not In') ind_plazo,
             a.sec_prestamo,
             decode(a.ind_sec_prestamo, 'S', 'In', 'Not In') ind_sec_prestamo
        From cb_rub_areas a
       Where (a.sec_capitulo Is Not Null Or a.mod_inf_rubro Is Not Null Or a.plazo Is Not Null Or
             a.sec_prestamo Is Not Null)
       and a.cod_area in(1016,1017);
   v_sec_capitulo  Varchar2(1000); --condición para el campo sec_capitulo
   v_mod_inf_rubro Varchar2(1000); --condición para el campo mod_inf_rubro
   v_plazo         Varchar2(1000);         --condición para el campo plazo
   v_sec_prestamo  Varchar2(1000);         --condición para el campo sec_prestamo
   --DYDMR-436
   v_msj_email     Varchar2(2000);     
   v_con_rub_sin_areas Number := 0;
   v_dir_correo_ent    ge_par_generales.dir_correo%type := fug_obt_dir_correo;
   v_dir_correo_par    varchar2(200) := fug_obt_pardinamico('EMAIL_RUB_AREA');

   --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
   procedure pr_ins_tab_temporal is
     PRAGMA AUTONOMOUS_TRANSACTION;
   begin
     
      Execute Immediate 'truncate table CB_RUBROS_TMP';
      Execute Immediate 'insert into CB_RUBROS_TMP(cod_rubro, cod_are_ant) (select r.cod_rubro, r.cod_area from cb_rubros r)';
      commit;
   end;

   --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
   procedure lp_act_rub_area(p_cod_rubro    cb_rubros.cod_rubro%type default null,
                             p_cod_rub_area cb_rub_areas.cod_area%type default null) is

   PRAGMA AUTONOMOUS_TRANSACTION;
   begin

         Update CB_RUBROS_TMP
            Set cod_area = p_cod_rub_area
          Where cod_rubro = p_cod_rubro
            and nvl(cod_area, 0) <> p_cod_rub_area;
          commit;
   end;


 --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
 procedure lp_act_cb_rubros is

 cursor c_rub_modificar is
   select x.cod_rubro, x.cod_area
     from cb_rubros_tmp x;
     
 ---Propósito: Actualizar solo los rubros que hayan cambiado el cód. de area
 begin
   --Eliminar los Rubros con areas iguales al anterior--
   delete from cb_rubros_tmp x
    where nvl(x.cod_area,9999) = nvl(x.cod_are_ant,9999);
   
   --Solo actualiza los rubros no eliminados, distintos--
   for det in c_rub_modificar loop
       --Actualizar solo rubros que quedaron y variaron su area--
       Update cb_rubros r
          Set r.cod_area = det.cod_area
        where r.cod_rubro = det.cod_rubro;
   end loop;
 end;


Begin
   -- obtengo la consulta dinamica de los rubros
   Execute Immediate v_sql_rubros
      Into v_sentencia;
   
   v_sentencia := Replace(v_sentencia,'cb_rubros','cb_rubros_tmp');     
   
   
   -- busco la cantidad de areas definidas
   Select Count(1)
     Into v_can_areas
     From cb_rub_areas a
    Where (a.sec_capitulo Is Not Null Or a.mod_inf_rubro Is Not Null Or a.plazo Is Not Null Or
          a.sec_prestamo Is Not Null);
   -- si no existen areas definidas, se emite msje. de error
   If v_can_areas = 0 Then
      raise_application_error(-20000, 'No existen áreas definidas.');
   Else
      --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
      -- insertar solo campo cod_rubro para procesar
       pr_ins_tab_temporal;
      -- reemplazo en la sentencia si hubiere &P_FILTROS por el valor del P_COD_RUBRO
      If instr(upper(v_sentencia), '&'||'P_FILTROS') > 0 Then
         If p_cod_rubro Is Not Null Then
            v_sentencia := Replace(v_sentencia,
                                   '&'||'P_FILTROS',
                                   'cod_rubro = ''' || p_cod_rubro || '''');
         Else
            v_sentencia := Replace(v_sentencia, '&'||'P_FILTROS', 'ROWNUM IS NOT NULL');
         End If;
      End If;
      -- abro el cursor de rubros
      Open c_cursor For v_sentencia;
      Loop
         Fetch c_cursor
            Into v_cod_rubro;
         Exit When c_cursor%Notfound;
         -- abro el cursor de areas
         For i In c_areas Loop
            -- condición para el sec_capitulo
            If i.sec_capitulo Is Null Then
               v_sec_capitulo := '1 = 1';
            Else
               v_sec_capitulo := 'substr(''' || v_cod_rubro || ''', 1, 2)' || i.ind_sec_capitulo || '(' || i.sec_capitulo || ')';
            End If;
            -- condición para el mod_inf_rubro
            If i.mod_inf_rubro Is Null Then
               v_mod_inf_rubro := '1 = 1';
            Else
               v_mod_inf_rubro := 'substr(''' || v_cod_rubro || ''', 6, 3)' || i.ind_mod_inf_rubro || '(' || i.mod_inf_rubro || ')';
            End If;
            -- condición para el plazo
            If i.plazo Is Null Then
               v_plazo := '1 = 1';
            Else
               v_plazo := 'substr(''' || v_cod_rubro || ''', 3, 1)' || i.ind_plazo || '(' || i.plazo || ')';
            End If;
            -- condición para el sector préstamo
            If i.sec_prestamo Is Null Then
               v_sec_prestamo := '1 = 1';
            Else
               v_sec_prestamo := 'substr(''' || v_cod_rubro || ''', 11, 3)' || i.ind_sec_prestamo || '(' ||
                                 i.sec_prestamo || ')';
            End If;
            -- arma la sentencia a ejecutar
            v_plsql := 'Select ' || i.cod_area || ' From Dual
                    Where ' || v_sec_capitulo || ' And ' || v_mod_inf_rubro || ' And ' ||
                       v_plazo || ' And ' || v_sec_prestamo;
            -- contador del cursor de areas
            v_con_areas := v_con_areas + 1;
            -- ejecuto la sentencia para buscar el area
            Begin
               Execute Immediate v_plsql
                  Into v_cod_area;
            Exception
               When no_data_found Then
                  -- si la cantidad de areas es igual al contador del cursor, entonces se emite msje. de error
                 --If v_con_areas = v_can_areas Then
                    -- abro el cursor de areas resto
                  --End If;
                  v_cod_area:= null;
               When Others Then
                  raise_application_error(-20000, 'Al ejecutar sentencia dinámica. ' || Sqlerrm);
            End;
            If v_cod_area Is Not Null Then
               -- se actualiza el rubro con el código de area
               Begin
                  --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
                  ---Actualización de area en tabla temporal
                  lp_act_rub_area(v_cod_rubro,v_cod_area);
                  -- se limpia la variable para la próxima consulta
                  v_cod_area := Null;
                  -- al encontrar un area, se actualiza cb_rubros y sale del loop de areas
                  Exit;
               End;
            End If;
         End Loop;
         -- se cera el contador del cursor de areas
         v_con_areas := 0;
      End Loop;
      --Para los rubrso restantes
      -- obtengo la consulta dinamica de los rubros
      v_sentencia:=null;
      Execute Immediate v_sql_rubros
         Into v_sentencia;
   
      v_sentencia := Replace(v_sentencia,'cb_rubros','cb_rubros_tmp');          
      
      -- reemplazo en la sentencia si hubiere &P_FILTROS por el valor del P_COD_RUBRO
      v_sentencia:= v_sentencia||' and a.cod_area is null ';
      If instr(upper(v_sentencia), '&'||'P_FILTROS') > 0 Then
         If p_cod_rubro Is Not Null Then
            v_sentencia := Replace(v_sentencia,
                                   '&'||'P_FILTROS',
                                   'cod_rubro = ''' || p_cod_rubro || '''');
         Else
            v_sentencia := Replace(v_sentencia, '&'||'P_FILTROS', 'ROWNUM IS NOT NULL');
         End If;
      End If;

      -- se incluye filtro para utilizar solo rubros con saldo
      v_sentencia := v_sentencia || 'And exists (select ''S'' from CB_SAL_CONSOLIDADOS_DIA sal
                where sal.fecha = (select max(fecha)from CB_SAL_CONSOLIDADOS_DIA)
                and sal.cod_rubro = a.cod_rubro)';

      -- abro el cursor de rubros
      Open c_cursor For v_sentencia;
      Loop
         Fetch c_cursor
            Into v_cod_rubro;
         Exit When c_cursor%Notfound;

          v_con_areas_resto:=0;
          For i In c_areas_resto Loop
                  -- condición para el sec_capitulo
                  If i.sec_capitulo Is Null Then
                     v_sec_capitulo := '1 = 1';
                  Else
                     v_sec_capitulo := 'substr(''' || v_cod_rubro || ''', 1, 2)' || i.ind_sec_capitulo || '(' || i.sec_capitulo || ')';
                  End If;
                  -- condición para el mod_inf_rubro
                  If i.mod_inf_rubro Is Null Then
                     v_mod_inf_rubro := '1 = 1';
                  Else
                     v_mod_inf_rubro := 'substr(''' || v_cod_rubro || ''', 6, 3)' || i.ind_mod_inf_rubro || '(' || i.mod_inf_rubro || ')';
                  End If;
                  -- condición para el plazo
                  If i.plazo Is Null Then
                     v_plazo := '1 = 1';
                  Else
                     v_plazo := 'substr(''' || v_cod_rubro || ''', 3, 1)' || i.ind_plazo || '(' || i.plazo || ')';
                  End If;
                  -- condición para el sector préstamo
                  If i.sec_prestamo Is Null Then
                     v_sec_prestamo := '1 = 1';
                  Else
                     v_sec_prestamo := 'substr(''' || v_cod_rubro || ''', 11, 3)' || i.ind_sec_prestamo || '(' ||
                                       i.sec_prestamo || ')';
                  End If;
                  -- arma la sentencia a ejecutar
                  v_plsql := 'Select ' || i.cod_area || ' From Dual
                          Where ' || v_sec_capitulo || ' And ' || v_mod_inf_rubro || ' And ' ||
                             v_plazo || ' And ' || v_sec_prestamo;
                  -- contador del cursor de areas
                  v_con_areas_resto := v_con_areas_resto + 1;
                  -- ejecuto la sentencia para buscar el area
                  Begin
                    Execute Immediate v_plsql
                        Into v_cod_area;
                  Exception
                     When no_data_found Then
                        -- si la cantidad de areas es igual al contador del cursor, entonces se emite msje. de error

                        If v_con_areas_resto = 2  then -- Solo hay 2 registros/--v_con_areas_resto Then
                           /*raise_application_error(-20000,
                                                   'Área del Rubro ' || v_cod_rubro || ' no encontrada.');*/
                           if v_msj_email is not null then
                              v_msj_email := v_msj_email || ', ';
                           end if;

                           v_msj_email := v_msj_email || v_cod_rubro;
                           v_con_rub_sin_areas := v_con_rub_sin_areas+1;
                        End If;
                     When Others Then
                        raise_application_error(-20000, 'Al ejecutar sentencia dinámica. ' || Sqlerrm);
                  End;
                  If v_cod_area Is Not Null Then
                     -- se actualiza el rubro con el código de area
                     Begin
                       --DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
                       ---Actualización de area en tabla temporal
                       lp_act_rub_area(v_cod_rubro,v_cod_area);
                        /*Update cb_rubros
                           Set cod_area = v_cod_area
                         Where cod_rubro = v_cod_rubro;*/
                        -- se limpia la variable para la próxima consulta
                        v_cod_area := Null;
                        -- al encontrar un area, se actualiza cb_rubros y sale del loop de areas
                        Exit;
                     End;
                  End If;

              End Loop;
       End Loop;

       ---DESOPIMI-26 -  Optimizar el proceso PRB_OBT_RUB_AREA - DYD-SDSL-3216
       ---Actualización de areas en cb_rubros
       lp_act_cb_rubros;

       --DYDMR-436
       if v_msj_email is not null then
          -- se arma el email
          v_msj_email := 'Se encontraron '|| v_con_rub_sin_areas || ' rubros sin configuracion de area: '||v_msj_email;
          --- Enviar correo
          it_mail.mail(v_dir_correo_ent,                   -- De:
                       v_dir_correo_par,                   -- Para:
                       'RUBROS SIN CONFIGURACION DE AREA', -- Asunto:
                       v_msj_email                         -- Mensaje:
                       );
       end if;
   End If;
Exception
   When Others Then
      If Sqlcode <= -20000 Then
         Raise;
      Else
         raise_application_error(-20000, 'Error en prb_obt_rub_area. ' || Sqlerrm);
      End If;
End;
/

