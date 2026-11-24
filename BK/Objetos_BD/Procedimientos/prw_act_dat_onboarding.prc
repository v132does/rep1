CREATE OR REPLACE PROCEDURE IT.prw_act_dat_onboarding(p_cod_persona   in ba_personas.cod_persona%TYPE,
                                                      p_tip_accion    in VARCHAR2,
                                                      p_cod_circuito  in NUMBER,
                                                      p_cod_error     out NUMBER,
                                                      p_msj_error     out VARCHAR2) IS



v_cod_persona       ba_personas.cod_persona%type;
v_customer_id       varchar2(50);


v_nro_telefono_aux  varchar2(30);
v_dir_correo_aux    varchar2(80);
v_pri_nombre_aux    ba_act_dat_onb_personas.pri_nombre%type;
v_pri_apellido_aux  ba_act_dat_onb_personas.pri_apellido%type;
v_seg_nombre_aux    ba_act_dat_onb_personas.seg_nombre%type;
v_seg_apellido_aux  ba_act_dat_onb_personas.seg_apellido%type;
v_principal_aux     ba_act_dat_onb_personas.seg_apellido%type;

v_pri_nombre        ba_act_dat_onb_personas.pri_nombre%type;
v_pri_apellido      ba_act_dat_onb_personas.pri_apellido%type;
v_seg_nombre        ba_act_dat_onb_personas.seg_nombre%type;
v_seg_apellido      ba_act_dat_onb_personas.seg_apellido%type;
v_principal         ba_act_dat_onb_personas.seg_apellido%type;
v_nro_telefono      varchar2(30);
v_dir_correo        varchar2(80);
g_msj_error         varchar2(4000); 
g_cod_error         number(20);

BEGIN

  g_cod_error := 000;
  g_msj_error := '';

  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;
       
    ---Si la operacion es aprobada
    IF p_tip_accion = 'A' THEN
       savepoint control;
       -- valida que persona sea valida
          begin
            select referencia
              into v_cod_persona
              from ba_tab_dat_adicionales c
             where referencia = p_cod_persona;
          exception
            when no_data_found then
              v_cod_persona := null;
            when too_many_rows then
              select referencia
                into v_cod_persona
                from ba_tab_dat_adicionales c
               where referencia = p_cod_persona
                 and trunc(c.fec_insercion) =
                     (select max(trunc(fec_insercion))
                        from ba_tab_dat_adicionales tt
                       where tt.referencia = c.referencia)
                 and rownum = 1;
            when others then
              v_cod_persona := null;
              g_cod_error := 001;
              g_msj_error := 'No se ha encontrado la persona en ba_tab_dat_adicionales . ' ||SQLERRM;
          end;  
          
       if v_cod_persona is not null then  
           -- obtenemos ID
              begin
                select id
                  into v_customer_id
                  from auth.auth_user@uenoprod
                 where code_person = p_cod_persona;
              exception
                when no_data_found then
                  v_customer_id := null;
                  g_cod_error := 002;
                  g_msj_error := 'No se ha encontrado la persona en el esquema AUTH . ' ||SQLERRM;
                when too_many_rows then
                  select id
                    into v_customer_id
                    from auth.auth_user@uenoprod
                   where code_person = p_cod_persona
                     and rownum = 1;
                when others then
                  v_customer_id := null;
                  g_cod_error := 003;
                  g_msj_error := 'No se ha encontrado la persona en el esquema AUTH . ' ||SQLERRM;
              end;   
      
             ---obtenemos los nuevos datos desde ba_act_dat_onb_personas
              begin
                select ob.pri_nombre,ob.pri_apellido,ob.seg_nombre,ob.seg_apellido,ob.telefono,ob.dir_correo,ob.principal
                  into v_pri_nombre_aux,v_pri_apellido_aux,v_seg_nombre_aux,v_seg_apellido_aux,v_nro_telefono_aux,v_dir_correo_aux, v_principal_aux
                  from ba_act_dat_onb_personas ob
                 where ob.cod_persona = p_cod_persona
                 and   ob.est_workflow = 'I';
              exception
                when others then
                  g_cod_error := 004;
                  g_msj_error := 'No se ha encontrado los datos en ba_act_dat_onb_personas . ' ||SQLERRM;
               end;   
            
             ---obtenemos los datos de ba_per_fisicas
               begin
                select f.pri_nombre,f.pri_apellido,f.seg_nombre,f.seg_apellido
                  into v_pri_nombre,v_pri_apellido,v_seg_nombre,v_seg_apellido
                  from ba_per_fisicas f
                 where f.cod_persona = p_cod_persona;
              exception
                when others then
                  g_cod_error := 005;
                  g_msj_error := 'No se ha encontrado los datos en ba_per_fisicas . ' ||SQLERRM;
               end; 
               

             ----actualizo la tabla ba_tab_dat_adicionales 
             if v_customer_id is not null and v_nro_telefono_aux is not null then
                   begin
                    select b.val_parametro
                      into v_nro_telefono
                      from ba_tab_dat_adicionales b
                     where b.referencia = p_cod_persona
                      and  b.parametro = 'CELULAR_ONBOARDING';
                  exception
                    when others then
                      g_cod_error := 006;
                      g_msj_error := 'No se ha encontrado los datos en ba_tab_dat_adicionales . ' ||SQLERRM;
                   end; 
             
              ---realizamos el update solo si el telefono es distinto al de ba_tab_dat_adicionales  
                 if v_nro_telefono_aux <> v_nro_telefono then 
                   begin
                      update  ba_tab_dat_adicionales c
                          set  c.val_parametro = v_nro_telefono_aux
                       where c.referencia = p_cod_persona
                       and   c.parametro = 'CELULAR_ONBOARDING';
                     exception
                       when others then
                     g_cod_error := 007;
                     g_msj_error := 'No se ha podido actualizar el Teléfono en ba_tab_dat_adicionales . ' ||SQLERRM;
                    end;
               ---actualizamos el telefono en ba_telefonos segun sea el Principal o No
                   if v_principal_aux = 'S' then      
                       begin
                        update  ba_telefonos t
                            set  t.telefono = v_nro_telefono_aux
                         where t.cod_persona = v_cod_persona
                         and   t.principal = 'S';
                       exception
                         when others then
                       p_cod_error := 009;
                       p_msj_error := 'No se ha podido actualizar el Teléfono en ba_telefonos . ' ||SQLERRM;
                      end;
                    else
                      begin
                        update  ba_telefonos t
                            set  t.telefono = v_nro_telefono_aux
                         where t.cod_persona = v_cod_persona
                         and   t.principal = 'N';
                       exception
                         when others then
                       p_cod_error := 010;
                       p_msj_error := 'No se ha podido actualizar el Teléfono en ba_telefonos . ' ||SQLERRM;
                      end;
                    end if;
                  
                    ---Actualizamos en el esquema AUTH de la base   
                     begin
                      update  auth.auth_user@uenoprod au
                          set  au.phone_number = v_nro_telefono_aux
                       where au.code_person = v_cod_persona
                       and   au.id = v_customer_id;
                     exception
                       when others then
                     g_cod_error := 011;
                     g_msj_error := 'No se ha podido actualizar el Teléfono en el esquema AUTH_USER . ' ||SQLERRM;
                    end;
                    
                     begin
                      update  auth.auth_user_app@uenoprod 
                          set  username = v_nro_telefono_aux
                       where   id = v_customer_id;
                     exception
                       when others then
                     g_cod_error := 012;
                     g_msj_error := 'No se ha podido actualizar el Teléfono en el esquema AUTH_USER_APP . ' ||SQLERRM;
                    end;   
                 end if;
             end if;    
     
             if v_customer_id is not null and v_dir_correo_aux is not null then
                  begin
                    select b.val_parametro
                      into v_dir_correo
                      from ba_tab_dat_adicionales b
                     where b.referencia = p_cod_persona
                      and  b.parametro = 'EMAIL_ONBOARDING';
                  exception
                    when others then
                      g_cod_error := 013;
                      g_msj_error := 'No se ha encontrado los datos en ba_tab_dat_adicionales . ' ||SQLERRM;
                   end; 
      
                ---realizamos el update solo si el correo es distinto al de ba_tab_dat_adicionales      
                  if v_dir_correo_aux <> v_dir_correo then 
                     begin
                         update  ba_tab_dat_adicionales c
                             set  c.val_parametro = v_dir_correo_aux
                          where c.referencia = p_cod_persona
                          and   c.parametro = 'EMAIL_ONBOARDING';
                        exception
                          when others then
                         g_cod_error := 014;
                         g_msj_error := 'No se ha podido actualizar el Email en ba_tab_dat_adicionales. ' ||SQLERRM;
                      end;
                     
                     begin
                         update  ba_personas p
                             set  p.dir_correo = v_dir_correo_aux
                          where   p.cod_persona = p_cod_persona;
                        exception
                          when others then
                         g_cod_error := 015;
                         g_msj_error := 'No se ha podido actualizar el Email en ba_personas. ' ||SQLERRM;
                      end; 
                  end if; 
             end if;  
     
             if v_customer_id is not null and v_pri_nombre_aux is not null then
                  if v_pri_nombre_aux <> v_pri_nombre then
                     begin
                         update  ba_per_fisicas f
                             set  f.pri_nombre   = v_pri_nombre_aux
                          where   f.cod_persona  = p_cod_persona;
                        exception
                          when others then
                         g_cod_error := 016;
                         g_msj_error := 'No se ha podido actualizar el primer nombre en ba_per_fisicas.'||SQLERRM;
                      end;
                  end if;  
             end if; 
             
              if v_customer_id is not null and v_pri_apellido_aux is not null then
                  if v_pri_apellido_aux <> v_pri_apellido then
                     begin
                         update  ba_per_fisicas f
                             set  f.pri_apellido   = v_pri_apellido_aux
                          where   f.cod_persona  = p_cod_persona;
                        exception
                          when others then
                         g_cod_error := 017;
                         g_msj_error := 'No se ha podido actualizar el primer apellido en ba_per_fisicas.'||SQLERRM;
                      end;
                  end if;  
             end if; 
             
             if v_customer_id is not null and v_seg_nombre_aux is not null then
                  if v_seg_nombre_aux <> v_seg_nombre then
                     begin
                         update  ba_per_fisicas f
                             set  f.seg_nombre   = v_seg_nombre_aux
                          where   f.cod_persona  = p_cod_persona;
                        exception
                          when others then
                         g_cod_error := 018;
                         g_msj_error := 'No se ha podido actualizar el segundo nombre en ba_per_fisicas.'||SQLERRM;
                      end;
                  end if;  
             end if; 
             
             if v_customer_id is not null and v_seg_apellido_aux is not null then
                  if v_seg_apellido_aux <> v_seg_apellido then
                     begin
                         update  ba_per_fisicas f
                             set  f.seg_apellido = v_seg_apellido_aux
                          where   f.cod_persona  = p_cod_persona;
                        exception
                          when others then
                         g_cod_error := 019;
                         g_msj_error := 'No se ha podido actualizar el segundo apellido en ba_per_fisicas.'||SQLERRM;
                      end;
                  end if;  
             end if; 
           
             if nvl(g_cod_error, '000') = '000' then
                    begin
                           update  ba_act_dat_onb_personas o
                             set  o.est_workflow   = 'F', o.cod_circuito = p_cod_circuito
                           where   o.cod_persona   =  p_cod_persona
                           and     o.est_workflow  =  'I';
                      exception
                          when others then
                         g_cod_error := 020;
                         g_msj_error := 'No se ha podido actualizar la tabla ba_act_dat_onb_personas.'||SQLERRM;
                      end;
             end if;
   
     end if;   
       ------Si la operacion es rechazada
  ELSIF p_tip_accion = 'R' THEN
    
            begin
              update wf_circuitos
              set estado = 'F'
              where cod_persona = p_cod_persona
              and cod_circuito = p_cod_circuito;
             exception
           when others then
             g_cod_error := 021;
             g_msj_error := 'No se pudo realizar el rechazo.'||SQLERRM;
           end;
  
  
  
            begin
              update  ba_act_dat_onb_personas o
              set  o.est_workflow = 'R' , o.cod_circuito = p_cod_circuito
              where   o.cod_persona   = p_cod_persona
              and     o.est_workflow  =  'I';
              exception
            when others then
              g_cod_error := 022;
              g_msj_error := 'No se ha podido actualizar la tabla ba_act_dat_onb_personas.'||SQLERRM;
            end;     
            

  END IF;
    if  nvl(g_cod_error, '000') <> '000' then
    rollback to control;
       p_cod_error := g_cod_error;
       p_msj_error := g_msj_error;
    else     
       p_cod_error  := g_cod_error;
       p_msj_error  := 'PROCESO CONCLUIDO CON EXITO.';
    end if;        


END;
/

