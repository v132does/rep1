create or replace procedure it.prg_td_act_datos(
p_cod_persona in varchar2,
p_cod_per_vinculo in varchar2,
p_tipo in varchar2,
p_telefono in varchar2 default null,
p_enviar_td in varchar2 default null, --Si recibe S , se envian mensajes
p_val_ant_sin_ges in varchar2 default null, --Campo para Act sin Gestor TD
p_val_nue_sin_ges in varchar2 default null, --Campo para Act sin Gestor TD
p_sin_verificar in varchar2 default null --Sin verificar Gestor S/N

) is
v_existe       VARCHAR2(1);
v_resultado    NUMBER(20);
v_mensaje      VARCHAR2(1000):= fug_obt_pardinamico('MSJ_INI_TOK_DIGITAL_PJ');
v_lugar        VARCHAR2(3000);
v_cod_telefono NUMBER;
v_es_td        VARCHAR2(1);
v_tipo         bw_td_configuraciones.tipo%TYPE;
v_tip_notif    VARCHAR2(1) := 'N';
v_user         ba_usuarios.cod_usuario%TYPE := substr(upper(USER), 1, 10);
begin
   
  pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1;
  if p_val_ant_sin_ges is null and p_val_nue_sin_ges is null then
    IF nvl(p_enviar_td,'N')='N' then

           v_existe:='N';
           v_lugar:='Verificar si existe en la tabla de configuraciones';
           begin
              select 'S', a.tipo
                into v_existe, v_tipo
                from bw_td_configuraciones a
               where a.cod_persona = p_cod_persona 
                 and a.cod_per_vinculo = p_cod_per_vinculo;
           exception
              when no_data_found then
                v_existe := 'N';
           end;

           begin

             if v_existe = 'S' then

                 v_lugar:='Upd. de Td Config. ';
                 if p_telefono is  not null then
                      v_lugar:='Actualizar config, upd.';
                      update bw_td_configuraciones a
                         set a.telefono= p_telefono,
                             a.sin_verificar=p_sin_verificar,
                             a.tipo=p_tipo
                       where a.cod_persona=p_cod_persona 
                         and a.cod_per_vinculo= p_cod_per_vinculo 
                         and a.tipo = v_tipo;
                       v_lugar:='Actualizar ba_telefonos upd.';
                        update ba_telefonos a
                           set a.telefono = p_telefono
                         where a.cod_persona = p_cod_per_vinculo
                           and a.tipo='T';
                     v_tip_notif := 'U'; -- actualizacion
                  else
                       v_lugar:='Borrar ba_telefonos ';
                       delete from ba_telefonos a
                         where a.cod_persona=p_cod_per_vinculo
                           and a.tipo='T';
                        v_lugar:='Borrar ba_telefonos ';
                       delete from bw_td_configuraciones a
                         where a.cod_per_vinculo=p_cod_per_vinculo
                           and a.cod_persona= p_cod_persona;
                           
                        v_tip_notif := 'E'; -- eliminacion
                  end if;
             else
                   v_lugar:='Insert. de Td Config. ';
                   insert into bw_td_configuraciones(cod_persona,cod_per_vinculo,tipo,
                               telefono,enviado,referencia,usu_insercion,
                               fec_insercion,usu_modificacion,fec_modificacion, sin_verificar)
                   values(p_cod_persona,p_cod_per_vinculo,p_tipo,
                               p_telefono,nvl(p_enviar_td,'N'),null,user,
                               sysdate,user,sysdate,p_sin_verificar);
                               
                   v_tip_notif := 'A'; -- insercion
                  v_cod_telefono:=0;
                  v_lugar:='Buscando en ba_telefonos ';
                  Begin
                    select nvl(max(cod_telefono),0)+1
                      into v_cod_telefono
                        from ba_telefonos
                          where cod_persona = p_cod_per_vinculo;
                  exception
                    when no_data_found then
                      v_cod_telefono:=1;
                    when others then
                      v_cod_telefono:=99;
                  end;
                  v_es_td:='N';
                  v_lugar:='Buscando en ta_telef. Si es TD ';
                  Begin
                   select 'S'
                     into v_es_td
                        from ba_telefonos
                          where cod_persona = p_cod_per_vinculo
                          and tipo='T';
                  exception
                    when no_data_found then
                      v_es_td:='N';
                    when others then
                      v_es_td:='N';
                  end;

                 if v_es_td='N' then
                         v_lugar:='Insert ba_telefonos ';
                        insert into BA_TELEFONOS (  COD_PERSONA          ,
                                                  TIPO                 ,
                                                  TIP_LINEA            ,
                                                  TELEFONO             ,
                                                  PRINCIPAL            ,
                                                  AREA                 ,
                                                  INTERNO              ,
                                                  OBSERVACION          ,
                                                  COD_TELEFONO          )
                                          Values( p_cod_per_vinculo    ,
                                                  'T'                ,
                                                  'C'                ,
                                                  p_telefono     ,
                                                  'N'                ,
                                                  NULL               ,
                                                  NULL               ,
                                                  NULL               ,
                                                  v_cod_telefono    );
                 else
                    v_lugar:='Actualizar ba_telefonos ';
                    IF p_telefono is not null then
                        update ba_telefonos a
                          set a.telefono=p_telefono
                           where a.cod_persona= p_cod_per_vinculo
                             and a.tipo='T';
                     else
                       v_lugar:='Borrar ba_telefonos ';
                       delete from ba_telefonos a
                         where a.cod_persona=p_cod_per_vinculo
                           and a.tipo='T';
                     end if;


                 end if;

             end if;

            exception
              when others then
               raise_application_error(-20000,'Error al grabar datos de Token Digital:'|| sqlerrm);
            end;
            commit;
            
       v_mensaje := 'Se ha %m el numero de token digital para el usuario '||fue_obt_nom_persona(p_cod_per_vinculo)||' perteneciente a la empresa '||fue_obt_nom_persona(p_cod_persona);
       case v_tip_notif
         when 'U' then v_mensaje := replace(v_mensaje, '%m', 'actualizado');
         when 'E' then v_mensaje := replace(v_mensaje, '%m', 'eliminado');
         when 'A' then v_mensaje := replace(v_mensaje, '%m', 'agregado');
         else v_mensaje := null;
       end case;
       
       if (instr(v_user, 'HBANK') > 0 or instr(v_user, 'BBVAAPIUSR') > 0) and v_mensaje is not null then
          v_resultado := paw_not.fu_env_email_prueba(fug_obt_pardinamico('SUE_DIR_MAI_CAPTACIONES'), v_mensaje, 'PRG_TD_ACT_DATOS');
          
          if v_resultado <> 0 then
            INSERT INTO ge_log_mail
               (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
            VALUES
               (sysdate,p_cod_per_vinculo,fug_obt_pardinamico('SUE_DIR_MAI_CAPTACIONES'),v_mensaje,v_resultado,null,to_char(sysdate,'hh24:mi:ss'),to_char(sysdate,'hh24:mi:ss'));
            commit;
          end if;
       end if;
    else
      if v_mensaje is not null then
           --Aqui enviamos los mensajes(Llamar al paw_not)
           v_lugar := 'Enviar mensaje Not.';
           v_resultado:= paw_not.fu_env_sms_prueba(p_telefono,v_mensaje, 'Alta Token Digital');
           --Actualizamos el registro en envadi
           --Ver que error retorna
           if v_resultado= 0 then
               v_lugar := 'Upd. Configuraciones';
               update bw_td_configuraciones a
                  set  a.enviado ='S'
                      where a.cod_persona=p_cod_persona and
                            a.cod_per_vinculo= p_cod_per_vinculo and
                            a.tipo=p_tipo;
                 commit;
           else
              v_lugar := 'Insertar en la tabla de Log';
              INSERT INTO ge_log_mail
                        (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
                     VALUES
                        (sysdate,p_cod_per_vinculo,p_telefono,'Alta TD Cliente -'||v_mensaje,v_resultado,null,to_char(sysdate,'hh24:mi:ss'),to_char(sysdate,'hh24:mi:ss'));

              commit;
           end if;
       end if;
    end if;

else

  --Para Actualizacion de datos de con o sin gestor de TD
  if p_val_ant_sin_ges = 'S' and p_val_nue_sin_ges = 'N' then
     --Borramos
     delete from ba_per_dat_adicionales a  where a.parametro='EMP_SIN_GES_TD'
     and a.cod_persona= p_cod_persona;
      commit;
  elsif p_val_ant_sin_ges = 'N' and p_val_nue_sin_ges = 'S' then
      --Insertamos
      insert into ba_per_dat_adicionales(cod_persona, parametro, val_parametro)
      values (p_cod_persona, 'EMP_SIN_GES_TD' ,'S');
      commit;
  end if;


end if;
  --

EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000, 'Error Ac.Dat: '||p_cod_persona||'/'||p_cod_per_vinculo||'-'||v_lugar||'-'|| sqlerrm);
end prg_td_act_datos;
/

