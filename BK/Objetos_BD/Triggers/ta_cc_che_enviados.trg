CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_ENVIADOS
  after Update or Insert on CC_CHE_ENVIADOS
  for each row

declare
   v_cod_persona      ba_personas.cod_persona%type;
   v_dir_correo_ent   ge_par_generales.dir_correo%type;
   v_cod_gestor       ba_personas.cod_persona%type;
   v_dir_cor_gerente  varchar2(100);
   v_cod_banca        ba_usuarios.cod_banca%type;
   v_dir_correo_ges   ba_usuarios.dir_correo%type;
   v_dir_correo_env   VARCHAR2(200);
   v_cta_lim_glo      lc_cta_cambios.nro_cuenta%type;
   v_dir_correo_par   varchar2(200);
   v_cuenta           varchar2(100);
   v_nro_cuenta       varchar2(50);
   v_banco            varchar2(50);
   v_cod_cau_devolucion ge_causales.cod_causa%type;
   
begin
   /*
   Favor emitir una alerta desde ITGF via correo electrónico 
   en caso que un cheque utilizado para operación de tesorería 
   haya sido devuelto por el motivo que fuere. 
   El correo debería ser direccionado a las personas a confirmar, 
   que pertenezcan a las áreas de Tesorería, seguimiento del Riesgo 
   --Obs: Para área de Comercial (Gestor del cliente en cuestión + Gerente de la banca)
   ya se busca y se envia para los demas se utiliza el parámetro dinàmico. 
   */
   v_dir_correo_ent := fug_obt_dir_correo;
   v_dir_correo_par:= fug_obt_pardinamico('EMAIL_CHE_DEV_CAM');
  --wa: 07/2013 Para enviar mail por cheque devuelto
  
  if updating and :new.estado ='D' then
         
        v_cod_persona:=null;
        v_cod_gestor:=null;
        v_dir_correo_ges:=null;
        v_nro_cuenta:= null;
        v_cuenta:= null;
        v_banco:=null;
        v_cod_cau_devolucion:= :new.cod_cau_devolucion;
        --********************************
        v_cta_lim_glo:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL');
        --Buscamos si es cheque de Cambios
        begin
           --Buscamos el codigo de Persona del Cliente
           select  trim(b.cod_persona),a.nro_cuenta, trim(a.denominacion)
            into v_cod_persona, v_nro_cuenta,v_cuenta
             from lc_cta_cambios a, ge_cta_clientes b
             where  a.nro_cuenta=b.nro_cuenta
             and a.nro_cuenta= :new.nro_cuenta;
         exception
          when no_data_found then
            v_cod_persona:=null;
          when others then
            v_cod_persona:=null;
         end;
         if :new.nro_cuenta <> v_cta_lim_glo
            or v_cod_persona is not null  then
        
            --Buscamos el còdigo del Banco
            begin
              select a.descripcion
                 into v_banco
                   from ge_bancos a
                      where a.cod_banco=:new.cod_banco;
            exception
                when others then
                   v_banco:=null;
             end;
          
            --Es un Cheque de Cambios y no es de la Cta. Generica
             if v_cod_persona is not null and v_nro_cuenta <> v_cta_lim_glo 
                and v_banco is not null then                  
                v_cod_gestor:=null;
                begin
                   v_cod_gestor:= FUG_OBT_COD_USU_OFICIAL(v_cod_persona);
                exception
                  when others then 
                     v_cod_gestor:= null;
                end;
                if v_cod_gestor is not null then
                        begin
                          v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
                        exception
                         when others then 
                            v_dir_correo_ges:= null;
                        end;
                        
                        --Buscamos la Banca si tiene
                        v_cod_banca:=null;
                        begin
                         select a.cod_banca
                          into v_cod_banca 
                           from ba_usuarios a 
                            where a.cod_usuario= v_cod_gestor
                             and a.estado='A'
                              and rownum=1;
                        exception
                          when no_data_found then
                              v_cod_banca:=null;
                          when others then
                              v_cod_banca:=null;
                        end;
                        
                        if nvl(v_cod_banca,0)<> 0 then
                          --Buscamos si esta parametrizado el mail a quien enviar
                          --se carga la dirección de mail en val_maximo, en el val_minimo el cod_banca
                          begin
                            select a.val_maximo
                             into v_dir_cor_gerente
                              from ba_cod_referencias a
                                where a.dominio='MAIL_GER_BANCA'
                                  and a.val_minimo=v_cod_banca;
                          exception
                             when no_data_found then
                                v_dir_cor_gerente:= null;
                             when others then
                                v_dir_cor_gerente:= null;
                          end;    
                         end if;
                  end if;

                 --- Enviar mail
                 if  v_dir_correo_ent is not null then
                    if v_dir_cor_gerente is not null and v_dir_correo_ges is not null then
                       v_dir_correo_env:= trim(v_dir_correo_ges)||'; '||trim(v_dir_cor_gerente)||'; '||trim(v_dir_correo_par);
                    elsif v_dir_cor_gerente is not null and v_dir_correo_ges is null then
                       v_dir_correo_env:= trim(v_dir_cor_gerente)||'; '||trim(v_dir_correo_par);
                    elsif v_dir_cor_gerente is null and v_dir_correo_ges is not null then
                       v_dir_correo_env:= trim(v_dir_correo_ges)||'; '||trim(v_dir_correo_par);
					else
                       v_dir_correo_env:= trim(v_dir_correo_par);
                    end if;

					begin
                    
                     it_mail.mail(v_dir_correo_ent,
                             v_dir_correo_env,
                             'Informe de Cheque Devuelto por Operaciones de Cambios',
                             'Le informamos que el Cheque Nro. : '||:new.nro_cheque ||', originado por la Operación de Cambios' ||chr(10)||
                             'Nro.: ' ||:new.nro_boleta ||', por el monto de: ' ||:new.monto ||' , en moneda:' ||:new.cod_moneda ||chr(10)||
                             'Correspondiente al Nro.de Cuenta: ' ||trim(v_nro_cuenta) ||' Denominación: ' ||trim(v_cuenta) ||chr(10)||
                             'Banco Emisor: ' ||trim(v_banco) ||' ,fecha de depósito: ' ||:new.fecha||', ha sido DEVUELTO.' ||chr(10)||
                             'Causa: '|| fug_obt_des_causa(v_cod_cau_devolucion)||chr(10)||
                             chr(13)||
                             'Se solicita proceder al seguimiento y realizar las gestiones respectivas con el cliente.'||chr(10)||
                             chr(13)
                             );
                        
                    exception
                      when others then
                          NULL;
                    end;
                 end if;
             end if;
         end if;

   end if;
   
   if inserting and :new.estado ='I' then

       update lc_retenciones a
          set a.cod_retencion = :new.cod_retencion,
              a.fec_fin       = :new.fec_final
        where a.nro_boleta = :new.nro_boleta
          and a.fec_inicio = :new.fecha;

   end if;

end TA_CC_CHE_ENVIADOS;
/

