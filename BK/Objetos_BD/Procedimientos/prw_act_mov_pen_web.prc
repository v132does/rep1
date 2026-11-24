CREATE OR REPLACE PROCEDURE IT.prw_act_mov_pen_web IS

v_fec_actual ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(1);
v_dir_correo_ent ge_par_generales.dir_correo%type;
v_dir_correo_cli  ba_usuarios.dir_correo%type;
--Movimientos pendientes de TTE-HB
cursor pendientes is
 select a.cod_per_principal,a.monto,a.nro_cuenta,a.cod_moneda,a.nro_documento,a.referencia
 from bw_mov_pendientes a
 where estado in ('P', 'E')
 and a.cod_tip_mensaje='227' -- TTE/HB
 and trunc(fec_hora) < v_fec_actual ;     

BEGIN
    --WA:20/10/2014 Para Operaciones TTE-HB se deberá enviar mail al cliente informándole que se anuló su operación  
      v_dir_correo_cli:=null;
      v_dir_correo_ent := fug_obt_dir_correo;
      for reg in pendientes loop   
        v_dir_correo_cli:=null;
        begin
            v_dir_correo_cli:= fug_obt_dir_mail_per(reg.cod_per_principal);
        exception
         when others then
             --Si tuvo problemas que no envíe al gestor, sólo a comex
             v_dir_correo_cli:=null;
        end;
 
        if v_dir_correo_cli is not null then
             begin  
                    it_mail.mail(v_dir_correo_ent,
                            v_dir_correo_cli,
                            'Informe de Transferencia Enviada Anulada, ingresada via Home Banking- Banco '||fug_obt_pardinamico('NOM_BANCO'),
                            'Buen día'||chr(10)||chr(10)||
                            'Su banco '||fug_obt_pardinamico('NOM_BANCO')||' le informa cuanto sigue: '||chr(10)||chr(10)||
                            'Su operación Nro.: '||reg.nro_documento||' , ha sido ANULADA en forma automática.'|| chr(10)||
                            'La misma no fué aprobada en el Home Banking en el horario convenido para el proceso correspondiente del día.'|| chr(10)|| chr(10)||
                            'Se le envía el presente mail para su conocimiento.'|| chr(10)||chr(10)||
                            'Favor comunicarse con el Departamento de Comercio Exterior o su Gestor ante cualquier consulta.'
                         );
             exception
                when others then 
                  --Si tiene error el envío , no debe dar error para seguri con operativa
                 null;
             end;
        end if;
   end loop; 
   
   
    --Anular registro relacionado en SIPAP - ge_snp_transferencias para dejar consistente--
    -- OCT/2017 DYDMR-7560 OMM- Se agrega comentario de la cancelación.
     update ge_snp_transferencias x
        set x.estado = 'C', --Cancelacion de Transaferencias no Aprobadas en el Dia--
           x.error = 'Cancelación automática en el Proceso de Inicio por Falta de autorización desde la WEB'
      where x.estado = 'S'
        and exists(select 1 
                     from bw_mov_pendientes t
                    where t.cod_tip_mensaje = '036' --SNP--
                      and t.estado IN ('P', 'E') --Pendiente--
                      and trunc(t.fec_hora) < v_fec_actual
                      and t.nro_ope_relacionada = x.nro_referencia);
   -- OMM 30/11/2010
   -- Actualiza a Anulado las autorizaciones pendientes de la Web de fechas anteriores.
   Begin
     update bw_mov_pendientes
        set estado = 'A'
     where estado IN ('P', 'E')
       and trunc(fec_hora) < trunc(v_fec_actual)
       AND cod_tip_mensaje NOT IN ('070','075','008');
   exception
       when others then
         null;
    end;
    
    Begin
     update bw_mov_pendientes
        set estado = 'A'
     where estado in ('P', 'E')
       and trunc(fec_insercion) < trunc(sysdate - 10)
       AND cod_tip_mensaje = '008';
   exception
       when others then
         null;
    end;

   Begin
     update bw_mov_pendientes
       set estado = 'A'
    where estado in ('P', 'E')
      and trunc(to_date(dato2,'DD/MM/YYYY')) < trunc(v_fec_actual)
      AND cod_tip_mensaje IN ('070','075');
   exception
       when others then
         null;
    end;
     --DDFADPER-8: Se actualizan los registros de actualización de datos personales cuyo tiempo de vigencia expiró.
    Begin
      update ba_act_dat_clientes 
             set estado = 'A' 
       where tip_solicitud in ('E','C') 
             and estado = 'P' 
             and trunc(fec_caducidad) < trunc(sysdate);
    exception
       when others then
         null;             
    end;	
END;
/

