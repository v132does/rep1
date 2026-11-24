create or replace procedure it.prs_act_est_catastro(p_cod_catastro in ge_spi_cat_comercios.cod_catastro%type,
                                                    p_estado       in ge_spi_cat_comercios.estado%type,
                                                    p_operacion    in varchar2,
                                                    p_mot_rechazo  in varchar2 default null) is

v_head        varchar2(1000);
v_body        varchar2(4000);
v_dir_noti    ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_MAI_CATASTRO_CLI');
v_reg_cat     ge_spi_cat_comercios%rowtype;
v_des_causa   ge_causales.descripcion%type;
begin
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
     select *
     into v_reg_cat
     from ge_spi_cat_comercios ct
     where ct.cod_catastro=p_cod_catastro;

    if p_operacion='A' then --alta
      if p_estado='A' then
         v_head:='Aprobacion de alta de catastro N° '||p_cod_catastro;
         v_body:='Se procedio a la autorizacion de la solicitud del castastro de referencia';
      else
         v_head:='Rechazo de solicitud catastro N° '||p_cod_catastro;
         v_body:='Se procedio al rechazo de la solicitud del castastro de referencia';
      end if;

    elsif p_operacion='S' then --suspension
       if p_estado='I' then
         v_head:='Aprobacion de suspension de catastro N° '||p_cod_catastro;
         v_body:='Se procedio a la autorizacion de la suspension del castastro de referencia';
      else
         v_head:='Rechazo de suspension catastro N° '||p_cod_catastro;
         v_body:='Se procedio al rechazo de la suspension del castastro de referencia';
         v_reg_cat.observacion:=null;
      end if;
    elsif  p_operacion='T' then --activacion
         if p_estado='A' then
            v_head:='Aprobacion de activacion de catastro N° '||p_cod_catastro;
            v_body:='Se procedio a la activacion del castastro de referencia';
         else
            v_head:='Rechazo de activacion de catastro N° '||p_cod_catastro;
            v_body:='Se procedio al rechazo de la activacion del castastro de referencia';
         end if;
    elsif p_operacion='M' then --modificacion
         if p_estado='A' then
            v_head:='Aprobacion de modificacion de catastro N° '||p_cod_catastro;
            v_body:='Se procedio a la modificacion del castastro de referencia';

            if v_reg_cat.cat_modificado is not null then
               update ge_spi_cat_comercios cm
               set cm.estado='M'
               where cm.cod_catastro= v_reg_cat.cat_modificado;
            end if;
         else
            v_head:='Rechazo de modificacion de catastro N° '||p_cod_catastro;
            v_body:='Se procedio al rechazo de la modificacion del castastro de referencia';
            begin
                select c.descripcion
                into v_des_causa
                from ge_par_causales d join ge_causales c
                on d.cod_causa=c.cod_causa
                where parametro='AFE_CIRCUITO'
                and d.cod_causa=p_mot_rechazo;
            exception
               when others then
                  v_des_causa:='No definido';
            end;

            v_reg_cat.observacion:=substr(v_reg_cat.observacion||'-'||p_mot_rechazo||'-'||v_des_causa,1,2000);
         end if;

    end if;
    v_body:= v_body||chr(10) ||'Persona: '||v_reg_cat.cod_persona||'-'||fue_obt_nom_persona(v_reg_cat.cod_persona)
             ||chr(10)||'Documento: '||pas_snp.fu_obt_nro_doc_persona(v_reg_cat.cod_persona)
             || chr(10) ||'Fecha inicio: '||to_char(v_reg_cat.fec_inicio,'DD/MM/YYYY')
             || chr(10) ||'Fecha vencimiento: '||to_char(v_reg_cat.fec_vencimiento,'DD/MM/YYYY')
             || chr(10) ||'Cuenta: '||v_reg_cat.nro_cuenta;

     update ge_spi_cat_comercios cc
     set cc.estado=p_estado,
     cc.observacion=v_reg_cat.observacion
     where cc.cod_catastro=p_cod_catastro;
     --envio de notificacion
     begin
          it_mail.mail( fug_obt_dir_correo,
                        v_dir_noti,
                        v_head,
                        v_body);

     exception
        when others then
            null;
     end;
exception
   when no_data_found then
     raise_application_error(-20000,'No se encuentra el castastro N° '||p_cod_catastro);
   when others then
      rollback;
      raise_application_error(-20001,'Error en la actualizacion del campo estado: '||sqlerrm);
end;
/

