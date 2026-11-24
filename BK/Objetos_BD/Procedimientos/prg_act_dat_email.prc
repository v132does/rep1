CREATE OR REPLACE PROCEDURE IT.PRG_ACT_DAT_EMAIL IS
 v_existe   varchar2(1);
 v_email    ba_mails.dir_correo%TYPE;
 v_return   VARCHAR(10);
 v_men_mail  VARCHAR2(2000);
 v_ant_email ba_mails.dir_correo%TYPE; 
  cursor c_cursor is
    select a.cod_persona, a.email
      from ba_act_dat_clientes a
     where a.estado = 'C'
       and a.migrado ='N'
       and a.tip_solicitud = 'E';
   procedure lp_act_migracion(p_cod_persona varchar2, p_email varchar2) is
     v_fecha date := sysdate;
   begin
     update ba_act_dat_clientes a
        set a.migrado = 'S',
            a.fec_migracion = v_fecha
      where a.cod_persona = p_cod_persona
        and a.email = p_email
        and a.estado = 'C'
        and a.tip_solicitud = 'E';
   end;

BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
  for c in c_cursor loop
    v_email := trim(c.email);
    v_ant_email := fug_obt_dir_mail_per(c.cod_persona);
    --verificar si existe el mail
     begin
       select 'S'
         into v_existe
         from ba_mails a
        where a.cod_persona = c.cod_persona
          and a.dir_correo = v_email
          and rownum = 1;
     exception
       when no_data_found then
         v_existe := 'N';
       when others then
         raise_application_error(-20000,'persona: '||c.cod_persona||sqlerrm);
     end;
      
      begin
        update ba_mails d set principal = 'N' where d.cod_persona = c.cod_persona  and d.principal = 'S';
      exception
      when others then
         raise_application_error(-20001,'Error al actualizar email principal en ba_mails. Cod Persona: '||c.cod_persona||sqlerrm);
      end;       
      if v_existe = 'N' then
        begin
          insert into ba_mails
            (cod_persona, tipo, dir_correo, principal)
          values
            (c.cod_persona, 'H', v_email, 'S');
        exception
            when others then
              raise_application_error(-20002,'Error insertar email, persona: '||c.cod_persona||sqlerrm);
        end;
      else
        begin
         update ba_mails d set principal = 'S' where d.cod_persona = c.cod_persona and d.dir_correo = v_email
         and rownum = 1;
        exception
         when others then
         raise_application_error(-20003,'Error al actualizar email principal en ba_mails. Cod Persona: '||c.cod_persona||sqlerrm);
        end;  
      end if; 
          
      begin          
        update ba_personas set dir_correo = v_email  where cod_persona = c.cod_persona;
      exception
      when others then
         raise_application_error(-20004,'Error al actualizar email en ba_personas. Cod Persona: '||c.cod_persona||sqlerrm);
      end; 
      lp_act_migracion(c.cod_persona,v_email);
          
      v_men_mail := fug_obt_pardinamico('ACT_DAT_CON_CAM_EMAIL');
      v_return := paw_not.fu_env_email_prueba(v_ant_email,
                                          utl_url.escape(v_men_mail,
                                          TRUE,
                                          'UTF-8'),
                                          'PAW_BEL');
      if v_return = 0 then
         insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
          values (fug_obt_dir_correo, v_ant_email, 'PRG_ACT_DAT_EMAIL - ret: '||v_return||'; Email de notificacion de cambio de email correctamente enviado a: '||v_ant_email,v_men_mail, sysdate, user);
      else
         insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
          values (fug_obt_dir_correo, v_ant_email, 'PRG_ACT_DAT_EMAIL - ret: '||v_return||'; Email de notificacion de cambio de email cambio NO enviado: '||v_ant_email,v_men_mail, sysdate, user);
      end if;                                              
   end loop;
END;
/

