create or replace procedure it.prg_glp_cotizacion(p_entrada  varchar2 default 'P',
                                                  p_tipo     varchar2 default 'A',
                                                  p_date     varchar2 default null,
                                                  p_bidPrice varchar2 default null,
                                                  p_askPrice varchar2 default null) is
                                               
/** El procedimiento se invoca desde:
      > Trigger tb_ge_cotizaciones
      > Proceso Independiente 8 - ALTA COTIZACION - GLOBAL PROCESSING
      > Job ALT_GLP_COTIZACION que se ejecuta a las 00:10:00 diariamente
-- El procedimiento inserta(Alta) o actualiza(Modificacion) la cotizacion en Global Processing
/** 
 p_entrada: T -> Trigger
            P -> Proceso Independiente
            J -> Job de base de datos
**/               
 v_pagaOtorEntiCodi varchar2(3);
 v_date             date;
 v_bidPrice         number(19,4);
 v_askPrice         number(19,4);
 v_cod_error        number(4);
 v_men_error        varchar2(4000);
 v_parametros       varchar2(1000);
 v_cod_programa     varchar2(50) := 'PRG_GLP_COTIZACION';
 v_pro_correcto     ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
 v_tipo             varchar2(1) default null;
 v_des_tipo         varchar2(50);
 v_cod_moneda       varchar2(3) := 'USD';
 v_entrada          varchar2(100);
 v_sender           varchar(100) := 'notificacion@elcomercio.com.py';
 v_recipients       varchar(100) := fug_obt_pardinamico('EMA_GLP_COTIZACION');
 
begin
  v_tipo := p_tipo;
  v_pagaOtorEntiCodi := fug_obt_pardinamico('COD_PRO_GLOBAL');
  
  if p_date is null then
   begin
    select a.fecha, a.val_com_autorizador, a.val_ven_autorizador
      into v_date, v_bidprice, v_askprice
      from ge_cotizaciones a
     where a.cod_moneda = v_cod_moneda
       and a.fecha = (select max(b.fecha)
                        from ge_cotizaciones b
                       where b.cod_moneda = a.cod_moneda
                         and b.val_com_autorizador is not null);
                        
   exception
     when others then
       null;
   end;
  else
    v_date     := p_date;
    v_bidprice := p_bidPrice;
    v_askprice := p_askPrice;
  end if;

 paj_glo.pr_web_cotizacion(v_tipo,
                           v_pagaOtorEntiCodi,
                           v_date,
                           v_bidPrice,
                           v_askPrice,
                           v_cod_error,
                           v_men_error);
                           
  if v_pro_correcto != v_cod_error then 
      if p_entrada = 'T' then
         v_entrada := 'TRIGGER TB_GE_COTIZACIONES';
      elsif P_ENTRADA = 'J' then
         v_entrada := 'JOB BASE DATOS - ALT_GLP_COTIZACION';
      else
         v_entrada := 'PROCESO INDEPENDIENTE 8 - ALTA COTIZACION - GLOBAL PROCESSING';
      end if;
      
      if v_tipo = 'A' then
       v_des_tipo := 'ALTA';
      elsif v_tipo = 'M' then
       v_des_tipo := 'MODIFICACION';
      end if;
      v_parametros := '>             tipo: '||v_tipo||chr(13)||
                      '> pagaOtorEntiCodi: '||v_pagaOtorEntiCodi||chr(13)||
                      '>             date: '||v_date||chr(13)||
                      '>         bidPrice: '||v_bidPrice||chr(13)||
                      '>         askPrice: '||v_askPrice;

      -- guarda en el log de errores --
      prg_ins_log_programas(v_cod_programa, 'Error de '||v_des_tipo||' en ge_cotizaciones.'||chr(13)||
                            'MsgErr: '||v_cod_error||' - '||v_men_error||chr(13)||
                            '# Origen del Proceso: '||v_entrada||chr(13)||
                            ' ***************************'||chr(13)||
                            ' *** Parametros Enviados ***'||chr(13)||
                            ' ***************************'||chr(13)||
                            v_parametros||chr(13)||
                            '.............................');
      -- Envia mail de error de cotizacion de autorizador en global
      if p_entrada = 'J' then
         it_mail.mail(v_sender,
                      v_recipients,
                      'Error de Cotizacion en Global Processing',
                      'Ocurrio un error al dar de alta la cotizacion en global procesing.'||chr(13)||
                      'Favor ejecutar Proceso Independiente(8)ALTA COTIZACION - GLOBAL PROCESSING');
      elsif p_entrada = 'P' then
         it_mail.mail(v_sender,
                      v_recipients,
                      'Error de Cotizacion en Global Processing',
                      'Ocurrio un error al dar de alta en global procesing.'||chr(13)||
                      'Favor verificar el error en log al ejecutar Proceso Independiente(8)ALTA COTIZACION - GLOBAL PROCESSING');
      end if;
   else
    -- Envia mail de confirmacion de cotizacion
    it_mail.mail(v_sender,
                 v_recipients,
                 'Alta Exitosa de cotizacion USD en Global Processing.',
                 'Alta de cotizaciones en global procesing con exito.');   
   end if;
 exception
   when others then
     null;
end prg_glp_cotizacion;
/

