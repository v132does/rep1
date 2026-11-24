create or replace procedure it.prp_env_mail(p_nro_solicitud in number,
                                            p_tipo          in varchar2,
                                            p_obs           in pr_solicitudes.observaciones%type
                                           ) is

  v_oficina     pr_solicitudes.cod_oficina%type;
  v_oficial     pr_solicitudes.cod_usu_promotor%type;
  v_descripcion pr_solicitudes.descripcion%type;
  v_monto       pr_solicitudes.monto%type;
  v_total       pr_solicitudes.tot_prestamo%type;
  v_plazo       pr_solicitudes.dia_plazo%type;
  v_fec_inicio  pr_solicitudes.fec_inicio%type;
  v_fec_apro    pr_solicitudes.fec_aprobacion%type;
 -- v_obs                     pr_solicitudes.observaciones%type;
  v_correo_oficial ba_usuarios.dir_correo%type;
  v_est_etq        varchar2(25);
  v_titulo         varchar2(25);

  cursor reg(p_oficina ba_oficinas.cod_oficina%type) is
    select s.correo
      from ge_enc_sucursal s
     where s.cod_oficina = p_oficina
       and nvl(s.estado, 'I') = 'A';

begin
  --buscamos la sucursal en donde se cargo la solicitud y ademas el oficial que lo cargo
  begin
    select s.cod_oficina,
           nvl(s.cod_usu_promotor, s.usu_insercion),
           s.descripcion,
           s.monto,
           s.tot_prestamo,
           s.dia_plazo,
           s.fec_inicio,
           s.fec_aprobacion
      into v_oficina,
           v_oficial,
           v_descripcion,
           v_monto,
           v_total,
           v_plazo,
           v_fec_inicio,
           v_fec_apro
      from pr_solicitudes s
     where s.nro_solicitud = p_nro_solicitud;
  exception
    when others then
      v_oficina := null;
      v_oficial := null;
  end;
  --buscamos el correo del oficial--
  begin
    select s.dir_correo
      into v_correo_oficial
      from ba_usuarios s
     where s.cod_usuario = v_oficial;
  exception
    when others then
      v_correo_oficial := null;
  end;

  if p_tipo = 'A' then
    v_est_etq := 'Aprobada';
    v_titulo  := 'Aprobacion';
  elsif p_tipo = 'D' then
    v_est_etq := 'Devuelta';
    v_titulo  := 'Devolucion';
  elsif p_tipo = 'R' then
    v_est_etq := 'Rechazada';
    v_titulo  := 'Rechazo';
  end if;

  for i in reg(v_oficina) loop
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    it_mail.mail(fug_obt_dir_correo,
                 i.correo,
                 'Notificacion de Estado Solicitud de Prestamo',
                 'Informamos que la solicitud de préstamo nro. : ' ||
                 p_nro_solicitud || ' fue  ' || v_est_etq || chr(10) ||
                 'Solicitud : ' || p_nro_solicitud || chr(10) ||
                 'Descripcion :' || v_descripcion || chr(10) || 'Monto : ' ||
                 v_monto || chr(10) || 'Monto Total : ' || v_total ||
                 chr(10) || 'Plazo : ' || v_plazo || chr(10) ||
                 'Fecha Inicio :' || v_fec_inicio || chr(10) || 'Fecha ' ||
                 v_titulo || ' :' || v_fec_apro || chr(10) ||
                 'Observacion : ' || p_obs || chr(10) || chr(10) ||
                 'Atentamente.');
  end loop;
  if v_correo_oficial is not null then
    it_mail.mail(fug_obt_dir_correo,
                 v_correo_oficial,
                 'Notificacion de Estado Solicitud de Prestamo',
                 'Informamos que la solicitud de préstamo nro. : ' ||
                 p_nro_solicitud || ' fue  ' || v_est_etq || chr(10) ||
                 'Solicitud : ' || p_nro_solicitud || chr(10) ||
                 'Descripcion :' || v_descripcion || chr(10) || 'Monto : ' ||
                 v_monto || chr(10) || 'Monto Total : ' || v_total ||
                 chr(10) || 'Plazo : ' || v_plazo || chr(10) ||
                 'Fecha Inicio :' || v_fec_inicio || chr(10) ||
                 'Fecha Aprobacion :' || v_fec_apro || chr(10) ||
                 'Observacion : ' || p_obs || chr(10) || chr(10) ||
                 'Atentamente.');
  end if;

end prp_env_mail;
/

