// Sets the icon and version information of the packaged UraxOS.exe without Wine (pure JS: resedit).
// Usage: node tools/set-exe-info.mjs <path to UraxOS.exe> <path to icon.ico> <version>
import fs from 'node:fs';
import * as ResEdit from 'resedit';
import * as PELibrary from 'pe-library';

const [exePath, icoPath, version = '0.5.0'] = process.argv.slice(2);
const exe = PELibrary.NtExecutable.from(fs.readFileSync(exePath), { ignoreCert: true });
const res = PELibrary.NtExecutableResource.from(exe);

const icon = ResEdit.Data.IconFile.from(fs.readFileSync(icoPath));
const group = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries)[0];
ResEdit.Resource.IconGroupEntry.replaceIconsForResource(
  res.entries, group ? group.id : 1, group ? group.lang : 1033, icon.icons.map((i) => i.data));

const vi = ResEdit.Resource.VersionInfo.fromEntries(res.entries)[0];
const v = version.split('.').map(Number).concat([0, 0, 0, 0]).slice(0, 4);
vi.setStringValues({ lang: 1033, codepage: 1200 }, {
  ProductName: 'UraxOS', FileDescription: 'UraxOS simulator', CompanyName: 'UraxOS project',
  LegalCopyright: 'UraxOS project', OriginalFilename: 'UraxOS.exe', InternalName: 'UraxOS',
  ProductVersion: version, FileVersion: version,
});
vi.setFileVersion(...v);
vi.setProductVersion(...v);
vi.outputToResourceEntries(res.entries);
res.outputResource(exe);
fs.writeFileSync(exePath, Buffer.from(exe.generate()));
console.log('exe info set:', exePath);
