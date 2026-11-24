create or replace force view it.ev_sesiones as
select sid, serial#, username usuario, nombre, status estado, osuser Operativo, machine maquina,
       terminal, program programa
 from ba_usuarios b, v$session where schemaname <> 'SYS'
 and STATUS <> 'KILLED'
 and b.cod_usuario = username;

