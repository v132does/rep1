create or replace procedure it.PRC_INS_PER_INHIBIDOS
(
   p_cod_persona     in ba_personas.cod_persona%type,
   p_nro_orden       in ge_per_inhibidas.nro_orden%type default null,
   p_cod_causa        ge_per_inhibidas.cod_causa%type,
   p_fec_inicio      in ge_per_inhibidas.fec_inicio%type,
   p_fec_vencimiento in ge_per_inhibidas.fec_vencimiento%type default null,
   p_origen          in ge_per_inhibidas.origen%type,
   p_estado          in ge_per_inhibidas.estado%type,
   p_modo            in varchar2,
   p_detalle         in varchar default null, 
   p_tip_circuito    in varchar default '5'

)
 is

 v_nro_orden    ge_per_inhibidas.nro_orden%type := 0;
 v_existe       varchar2(1) := 'N';
 v_cod_causa    ge_per_inhibidas.cod_causa%type := nvl(fug_obt_pardinamico('EST_CAU_INHIBICION'),123);
 v_origen       ge_per_inhibidas.origen%type :=  nvl(fug_obt_pardinamico('MOT_ORI_INHIBICION'),'PEP');
 v_nom_programa varchar2(50) := 'PRC_INS_PER_INHIBIDOS';
 v_lugar        varchar2(100);
 v_des_mail      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DES_MAI_INHIBICION');
 v_Detalle    ge_per_inhibidas.detalle%type;

begin



begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

Select substr(p_detalle, 1, 2000)
  into v_detalle
from dual;

--Verifico que ya no exista persona como inhibido.
begin
 select 'S' 
     into v_existe
 from ge_per_inhibidas a
  where cod_persona = p_cod_persona
  and a.cod_causa = v_cod_causa
  and a.estado = 'I'; -- inhibido

exception
  when no_data_found then
    v_existe := 'N';
  when too_many_rows then
    v_existe := 'S';
  when others then
    raise_application_error(-20000, ' Error  ' || sqlerrm);
     v_lugar := '01';
end;

 -- numerador
 select nvl(max(nro_orden),0) + 1
     into v_nro_orden
 from ge_per_inhibidas a
  where cod_persona = p_cod_persona;

  if (v_existe = 'N' and upper(p_modo) = 'INS') then
      begin
        insert into GE_PER_INHIBIDAS (
               COD_PERSONA,
               NRO_ORDEN,
               COD_CAUSA,
               FEC_INICIO,
               FEC_VENCIMIENTO,
               ORIGEN,
               ESTADO,
         DETALLE)
        values (
                 p_cod_persona,
                 v_nro_orden,
                 nvl(p_cod_causa, v_cod_causa),
                 nvl(p_fec_inicio, trunc(sysdate)),
                 p_fec_vencimiento,
                 nvl(p_origen, v_origen),
                 upper(p_estado),
                 v_Detalle);
                 

if nvl(p_tip_circuito,'5') = '7' then  --para las notificaciones de vigia
       -- Envia notificacion al area de cumplimiento
         it_mail.mail(fug_obt_dir_correo, --mail remitente
                      v_des_mail, --mail destinatarios
                      'Coincidencia en listas de VIGIA', --asunto
                      -- body --
                      'Se genero una tarea WF Verificación Personas Parecidas Vigía' ||chr(10) ||
                      'Favor verificar al cliente, codigo de persona : ' || p_cod_persona || chr(10) ||
                      'Atentamente.');
else 
       -- Envia notificacion al area de cumplimiento
         it_mail.mail(fug_obt_dir_correo, --mail remitente
                 v_des_mail, --mail destinatarios
                 'Aprobacion Cumplimiento PEP', --asunto
                  -- body --
                 'Se genero una tarea WF Aprobación Cumplimiento PEP' ||chr(10) ||
                 'Favor verificar al cliente, codigo de persona : ' || p_cod_persona || chr(10) ||
                 'Atentamente.');
end if;

       exception
         when others then
           raise_application_error(-20001, ' Error: ' || sqlerrm) ;
           v_lugar := '02';
           prg_ins_log_programas(v_nom_programa,
                              substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              0);
      end;

    elsif upper(p_modo) = 'UPD' then
        update ge_per_inhibidas a
         set a.estado = upper(p_estado)
        where cod_persona = p_cod_persona
        and a.cod_causa = v_cod_causa
        and a.estado =  'I' ;
    end if;
    commit;
exception
  when others then
    raise_application_error(-20002, ' Error  ' || sqlerrm);
    v_lugar := '03';
    prg_ins_log_programas(v_nom_programa,
                    substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                           1,
                           4000),
                    p_cod_persona,
                    0);
end; -- PRC_INS_PER_INHIBIDOS;
/

